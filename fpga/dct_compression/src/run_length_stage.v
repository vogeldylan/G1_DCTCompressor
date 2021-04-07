`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
//
// Module Name: run_length_stage.v
// Description:
//  performs run length encoding and de-transposes the DCT coefficients
//
// Last Modified: 2021-03-28
//
//////////////////////////////////////////////////////////////////////////////////


module run_length_stage #(
    DATA_WIDTH = 14, // an illusion of choice, they need to be 15-bit for the fifo
    OUTPUT_WIDTH = 16
)(
    input i_clk,
    input i_resetn,
    // to avoid conflicts we write two values at once at sequential addresses
    input [DATA_WIDTH-1 : 0] i_data0,
    input [DATA_WIDTH-1 : 0] i_data1, // 16-bit wide
    input wen,

    // reading
    output [OUTPUT_WIDTH-1 : 0] o_data0, // 16-bit wide
    output [OUTPUT_WIDTH-1 : 0] o_data1, // 16-bit wide
    output reg rsync // sync the reader reads

    );

    /* LOCAL PARAMETERS */
    localparam ADDR_WIDTH = 6;  // this is an illusion of choice
    localparam MAX_COUNT = 2**ADDR_WIDTH;  // highest number of inputs we can count
    localparam PAD_WIDTH = OUTPUT_WIDTH-DATA_WIDTH; // how many zeros we need to pad in front of non-zero numbers to make them 16 bit

    // impossble to get all 1's in my encoding scheme, thus set as EOF
    localparam EOF = {OUTPUT_WIDTH{1'b1}};

    /* RUN-LENGTH OUTPUT BUFFER */
    reg [ADDR_WIDTH : 0] curr_ptr; // current write pointer
    reg [ADDR_WIDTH : 0] read_ptr; // current read pointer
    reg [ADDR_WIDTH : 0] last_ptr; // largest pointer that we wrote to last cycle
    // 2D double buffer, one page for writing and one for reading
    reg [OUTPUT_WIDTH-1 : 0] run_length_buf [0:1][0 : 2**ADDR_WIDTH];
    reg wpage; // current write page
    wire rpage; // current read page
    reg w_done;

    // rpage should be the opposite of wpage
    assign rpage = ~wpage;

    /* RUN-LENGTH VARIABLES */
    reg [5 : 0] zero_count; // use the upper 6 bits of zero addresses as the count // note, a zero zero count currently means 64
    reg [ADDR_WIDTH : 0] n_data_processed; // keep track of how many bytes we've processed

    /* OUTPUT AND INPUT DATA VARIABLES */
    // input
    wire [(DATA_WIDTH*2)-1 : 0] i_data_dbl; // store the 2-wide input as ... two-wide
    assign i_data_dbl = {i_data1, i_data0};

    // fifo output
    wire [(DATA_WIDTH*2)-1 : 0] curr_data_dbl;
    wire [DATA_WIDTH-1 : 0] curr_data0, curr_data1;
    
    assign {curr_data1, curr_data0} = curr_data_dbl; // unstack the fifo output data into two variables
    
    wire fifo_rden_rdy, fifo_full, fifo_empty, fifo_rst; // fifo signals
    reg fifo_rden; // signal that the fifo_rden signal is ready

    // output
    reg [OUTPUT_WIDTH-1 : 0] o_data0_reg;
    reg [OUTPUT_WIDTH-1 : 0] o_data1_reg;
    reg rsync_ready;
    assign o_data0 = o_data0_reg; // output assignments
    assign o_data1 = o_data1_reg;

    assign fifo_rst = ~i_resetn;


    // fifo_rden_rdy should only be asserted if the fifo is not empty, and if we're done reading the last buffer
    // need some way of updating n_data_processed as well
    // rden asserted if not empty AND
    //      current read_ptr will read the last data in the buffer OR
    //      we haven't yet processed a full buffer's worth of data
    wire data_processed_flag;
    assign data_processed_flag = ((read_ptr+1) >= last_ptr || !(n_data_processed==MAX_COUNT) || (n_data_processed==MAX_COUNT && rsync_ready));
    assign fifo_rden_rdy = !fifo_empty && data_processed_flag;

    // instantantiate the outptut fifo
    // needs to be 32 (30?) bit wide
    fifo_generator_1 axis_fifo(
        .clk(i_clk),
        .rst(fifo_rst),
        .din(i_data_dbl),
        .wr_en(wen),
        .rd_en(fifo_rden_rdy),
        .dout(curr_data_dbl),
        .full(fifo_full),
        .empty(fifo_empty)
    );


    initial fifo_rden = 0;
    always @(posedge i_clk) begin
        if (!i_resetn) begin
            fifo_rden <= 0;
        end
        else begin
            // one clock cycle delay
            fifo_rden <= fifo_rden_rdy;
        end
    end

    // handle n_data_processed
    // should increment every time we read data from the fifo
    initial n_data_processed = 0;
    always @(posedge i_clk) begin
        if (!i_resetn) begin
            n_data_processed <= 0;
        end
        else begin
            if (fifo_rden && !(n_data_processed==MAX_COUNT)) begin
                // it means that we are reading, and it's likely because n_data_processed is not max
                n_data_processed <= n_data_processed + 2; // once we've latched the data, update how many we've processed
            end
            else if (fifo_rden && (n_data_processed==MAX_COUNT)) begin
                // we're reading, and yet n_data_processed is equal to max_count. This means that we must be about
                // to finish reading from the read buffer, and can process more data
                n_data_processed <= 2; // we'll process two bytes this cycle
            end
        end
    end

    // handle w_done
    // this should just track every time we finish a write, for bookeeping
    // it should be reset once we begin writing to a new block
    initial w_done = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            w_done <= 0;
        end
        else begin
            if (n_data_processed==MAX_COUNT-2 && fifo_rden)
                // we're finishing a write cycle
                w_done <= 1;
            else if (n_data_processed==MAX_COUNT)
                // we're starting a cycle anew
                w_done <= 0;
        end
    end

    // handle rsync_ready
    // rsync_ready should go high on the last cycle of writing data
    initial rsync_ready = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            rsync_ready <= 0;
        end
        else begin
            if (n_data_processed==(MAX_COUNT-2) && fifo_rden && !rsync_ready) begin
                // if rsync is low and we finished writing a block, set high
                rsync_ready <= 1;
            end
            else if (rsync_ready && (read_ptr+1)>=last_ptr && !w_done && !(n_data_processed==(MAX_COUNT-2) && fifo_rden)) begin
                // if rsync_ready is already high AND
                //  the current read_ptr will read the last data in the read buffer AND
                //  we haven't finished a transfer previously AND
                //  we're not ABOUT to finish a transfer
                // then set rsync_ready low
               rsync_ready <= 0;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync_ready <= rsync_ready;
            end
        end
    end

    // handle rsync
    // rsync should just lag rsync_ready by one cycle
    initial rsync = 0;
    always @(posedge i_clk) begin
        if(!i_resetn) begin
            rsync <= 0;
        end
        else begin
            if (rsync_ready) begin
                // if rsync is low and we finished writing a block, set high
                rsync <= 1;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync <= 0;
            end
        end
    end

    // handle reading data from run_length_buf
    initial begin
        read_ptr = 0;
        o_data0_reg = 0;
        o_data1_reg = 0;
    end
    always @(posedge i_clk) begin
        if (!i_resetn) begin
            read_ptr <= 0;
            o_data0_reg <= 0;
            o_data1_reg <= 0;
        end
        else begin
            if (rsync_ready && (read_ptr + 2) <= last_ptr) begin
                // next +2 will either be lower or equal to last ptr
                o_data0_reg <= run_length_buf[rpage][read_ptr];
                o_data1_reg <= run_length_buf[rpage][read_ptr + 1];
                read_ptr <= read_ptr + 2;
            end
            else if (rsync_ready && (read_ptr + 1) == last_ptr) begin
                // if last one didn't get called, it means that read_ptr + 1 is likely equal to last_ptr, hence we have to stop here
                o_data0_reg <= run_length_buf[rpage][read_ptr];
                o_data1_reg <= run_length_buf[rpage][read_ptr + 1];
//                read_ptr <= read_ptr + 2;
                // set back to zero, rsync_ready will handle disabling the read
                read_ptr <= 0;
    
            end
            else if (rsync_ready && read_ptr == last_ptr) begin
                // exactly one more data left
                o_data0_reg <= run_length_buf[rpage][read_ptr]; // output last data, which should be EOF
                o_data1_reg <= EOF; // output an extra EOF, just to pad
//                read_ptr <= read_ptr + 1;
                // set back to zero, rsync_ready will handle disabling the read
                read_ptr <= 0;
            end
        end
    end

    // some flags for figuring out how to write
    wire [3 : 0] flags;
    assign flags = {(zero_count != 0), (curr_data0 == 0 || curr_data0 == {DATA_WIDTH{1'b1}}), (curr_data1==0 || curr_data1=={DATA_WIDTH{1'b1}}), ((n_data_processed+2)==MAX_COUNT)};

    integer i;
    initial begin
        // reset all the signals
        curr_ptr <= 0;
        last_ptr <= 0;
        wpage <= 0;
        zero_count <= 0;
        for (i = 0; i <= 2**ADDR_WIDTH; i=i+1) begin
            run_length_buf[0][i] <= 0;
            run_length_buf[1][i] <= 0;
        end
    end
    always @(posedge i_clk) begin
        if (!i_resetn) begin
            // reset all the signals
            curr_ptr <= 0;
            last_ptr <= 0;
            wpage <= 0;
            zero_count <= 0;
            for (i = 0; i < 2**ADDR_WIDTH; i=i+1) begin
                run_length_buf[0][i] <= 0;
                run_length_buf[1][i] <= 0;
            end
        end
        else begin
            if (fifo_rden) begin
                casez (flags)
                    // is end of packet
                    4'b0001: begin
                        // last data not zero, none of these datas zero, max count
                        run_length_buf[wpage][curr_ptr] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        run_length_buf[wpage][curr_ptr+1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        run_length_buf[wpage][curr_ptr+2] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 2;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b0011: begin
                        // last data not zero, current data0 is non-zero, current data1 is zero, at max count
                        run_length_buf[wpage][curr_ptr] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        run_length_buf[wpage][curr_ptr + 1][14:0] <= {6'b1, 9'b0}; // indicate the zero
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 2] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 2;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b0101: begin
                        // last data not zero, current data0 is zero, current data1 is not zero, not at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {6'b1, 9'b0}; // top bit one for zero, bottom bits zero
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        run_length_buf[wpage][curr_ptr + 2] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 2;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b?111: begin
                        // doesn't matter what zero count is, end of packet
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count+2, 9'b0};
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 1;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b1001: begin
                        // last data zero, both current datas not zero, at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count, 9'b0}; // last count is correct, store
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data0}; // store the current data
                        run_length_buf[wpage][curr_ptr + 2] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        run_length_buf[wpage][curr_ptr + 3] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 3;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b1101: begin
                        // last data zero, next data zero, data1 not zero, at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count+1, 9'b0}; // write current value + 1
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        run_length_buf[wpage][curr_ptr + 2] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 2;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    4'b1011: begin
                        // last data zero, next data not zero, data1 zero, at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count, 9'b0};
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        run_length_buf[wpage][curr_ptr + 2] <= {1'b1, 6'b1, 9'b0}; // encode data 1
                        run_length_buf[wpage][curr_ptr + 3] <= EOF;
                        // increment the pointers
                        curr_ptr <= 0;
                        last_ptr <= curr_ptr + 3;
                        // update wpage and zero count
                        wpage = ~wpage;
                        zero_count <= 0;
                    end
                    // not end of packet
                    4'b0000: begin
                        // last data not zero, none of these datas zero
                        run_length_buf[wpage][curr_ptr] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        run_length_buf[wpage][curr_ptr+1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        // increment the current pointer
                        curr_ptr <= (curr_ptr + 2) % 2**ADDR_WIDTH;
                    end
                    4'b0010: begin
                        // last data not zero, current data0 is non-zero, current data1 is zero, not at max count
                        run_length_buf[wpage][curr_ptr] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        // increment the current pointer
                        curr_ptr <= (curr_ptr + 1) % 2**ADDR_WIDTH;
                        zero_count <= 1; // reset the count
                    end
                    4'b0100: begin
                        // last data not zero, current data0 is zero, current data1 is not zero, not at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {6'b1, 9'b0}; // top bit one for zero, bottom bits zero
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        // increment the current pointer
                        curr_ptr <= (curr_ptr + 2) % 2**ADDR_WIDTH;
                        zero_count <= 0; // reset the count
                    end
                    4'b?110: begin
                        // don't care what zero count is, increment it
                        zero_count <= zero_count + 2; // just increment zero count
                    end
                    4'b1000: begin
                        // last data zero, both current datas not zero, not at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count, 9'b0}; // last count is correct, store
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data0}; // store the current data
                        run_length_buf[wpage][curr_ptr + 2] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        // increment current pointer by 3!
                        curr_ptr <= (curr_ptr + 3) % 2**ADDR_WIDTH;
                        zero_count <= 0; // reset the zero count
                    end
                    4'b1100: begin
                        // last data zero, next data zero, data1 not zero
                        // run_length_buf[wpage][curr_ptr] <= {1'b1, zero_count+1, 9'b0}; // write current value + 1
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count+1, 9'b0};
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data1};
                        // increment current pointer by 2
                        curr_ptr <= (curr_ptr + 2) % 2**ADDR_WIDTH;
                        zero_count <= 0;
                    end
                    4'b1010: begin
                        // last data zero, next data not zero, data1 zero, not at max count
                        run_length_buf[wpage][curr_ptr][14:0] <= {zero_count, 9'b0};
                        run_length_buf[wpage][curr_ptr][15] <= 1'b1;
                        run_length_buf[wpage][curr_ptr + 1] <= {{PAD_WIDTH{1'b0}}, curr_data0};
                        // increment current pointer by 2
                        curr_ptr <= (curr_ptr + 2) % 2**ADDR_WIDTH;
                        zero_count <= 1; // reset to one for data1 value
                    end
                    // default:
                endcase
            end
        end
    end



endmodule