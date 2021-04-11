`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: zig_zag_stage.v
// Description:
//  performs zig-zag ordering of the DCT coefficient
//
// Last Modified: 2021-03-16
//
//////////////////////////////////////////////////////////////////////////////////


module zig_zag_stage #(
    DATA_WIDTH = 8, // this is an illusion of choice
    ADDR_WIDTH = 6 // this is also and illusion of choice
)(
    input i_clk,
    input i_resetn,
    // to avoid conflicts we write two values at once at sequential addresses
    input signed [DATA_WIDTH-1 : 0] wdata0, wdata1,
    input wen,

    // reading
    output signed [DATA_WIDTH-1 : 0] rdata0, rdata1,
    output reg rsync // sync the reader reads

    );
//    localparam DATA_NBITS = $clog2(DATA_WIDTH);
    localparam DATA_NBITS = 3; 
    localparam ADDR_WIDTH_HALF = ADDR_WIDTH>>1;

    // create internal signals
    // transpose buffer
    reg [DATA_WIDTH-1 : 0] ram_buf [0: 1][0 : 2**ADDR_WIDTH_HALF-1][0 : 2**ADDR_WIDTH_HALF-1];
    // output buffers
    reg [DATA_WIDTH-1 : 0] reg_rdata0, reg_rdata1;
    // internal waddr and raddr
    reg [ADDR_WIDTH-1 : 0] waddr, raddr, zz_raddr0, zz_raddr1;
    // which page of memory to read/write from
    reg wpage;
    wire rpage;
    reg rsync_ready, w_done;
    
    // create the zig-zag lut
    reg [ADDR_WIDTH-1 : 0] zigzag_lut [0 : 2**ADDR_WIDTH - 1];
    initial begin
        $readmemh("zigzag_lookup.mem", zigzag_lut, 0, 63);
    end


    // ensure that the read and write pages are opposite
    assign rpage = ~wpage;

    // assign outputs
    assign rdata0 = reg_rdata0;
    assign rdata1 = reg_rdata1;

    // handle wpage
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            wpage <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen) begin
                // we're at the last write address and are writing
                wpage <= ~wpage;
            end
        end
    end

    // handle incrementing waddr
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset raddr
            waddr <= 0;
        end
        else begin
            if (wen) begin
                // should wrap once it's full?
                waddr <= waddr + 2;
            end
        end
    end

    // handle writing to the ram
    integer i;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the buffers
            for (i = 0; i < 2**ADDR_WIDTH-1 ; i=i+1) begin
                ram_buf[wpage][(i%8)+0][i>>DATA_NBITS] <= 0;
                ram_buf[wpage][(i%8)+1][i>>DATA_NBITS] <= 0;
            end 
        end
        else begin
            if (wen) begin
                // write to the buffer if the master enables writes
//                ram_buf[wpage][row][col]
//                 normally we would increment columns, and write a row at a time
//                  for the double buffer we want to increment rows, and write a column at a time
                ram_buf[wpage][(waddr%8)+0][waddr>>DATA_NBITS] <= wdata0;
                ram_buf[wpage][(waddr%8)+1][waddr>>DATA_NBITS] <= wdata1;
            end
        end
    end

    // handle incrementing raddr
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset raddr
            raddr <= 0;
            zz_raddr0 <= 0;
            zz_raddr1 <= 1;
        end
        else begin
            if (rsync_ready) begin
                // should wrap once full, write once we're ready to write
                raddr <= (raddr + 2) % 2**ADDR_WIDTH;
                // fetch the correct zig-zag read addresses from memory
                // this works because the data is written into the buffer transposed
                zz_raddr0 <= zigzag_lut[(raddr + 2) % 2**ADDR_WIDTH];
                zz_raddr1 <= zigzag_lut[(raddr + 3) % 2**ADDR_WIDTH];
            end
        end
    end

    // handle rsync
    // rsync should go high once we're done
    always @(posedge i_clk) begin
        if(~i_resetn) begin
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

    // handle w_done
    // this should just track every time we finish a write, for bookeeping
    initial w_done = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            w_done <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen)
                w_done <= 1;
            else if (waddr == 0)
                w_done <= 0;
        end
    end

    // handle rsync
    // rsync should go high once we're done
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            rsync_ready <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen && !rsync_ready) begin
                // if rsync is low and we finished writing a block, set high
                rsync_ready <= 1;
            end
            else if (raddr == 2**ADDR_WIDTH-2 && rsync_ready && !w_done && !(waddr == 2**ADDR_WIDTH-2)) begin
                // if we're about to finish reading, but not done writing, clear
                rsync_ready <= 0;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync_ready <= rsync_ready;
            end
        end
    end

    // handle reading from the ram
    always @(posedge i_clk) begin
        reg_rdata0 <= ram_buf[rpage][zz_raddr0>>DATA_NBITS][zz_raddr0%8];
        reg_rdata1 <= ram_buf[rpage][zz_raddr1>>DATA_NBITS][zz_raddr1%8];
    end


endmodule


//module run_length_lut#(
//    // this module is unused once I figured out the python algorithm
//    ADDR_WIDTH = 6 // also an illusion of choice
//)(
//    input [2**ADDR_WIDTH - 1 : 0] i_index,
//    output reg [2**ADDR_WIDTH - 1 : 0] o_index
//);
      
//    always @(*) begin
//        case(i_index)
//            'h00 : o_index <= 'h00;     'h01 : o_index <= 'h08;     'h02 : o_index <= 'h01;     'h03 : o_index <= 'h02;
//            'h04 : o_index <= 'h09;     'h05 : o_index <= 'h10;     'h06 : o_index <= 'h18;     'h07 : o_index <= 'h11;
//            'h08 : o_index <= 'h0A;     'h09 : o_index <= 'h03;     'h0A : o_index <= 'h04;     'h0B : o_index <= 'h0B;
//            'h0C : o_index <= 'h12;     'h0D : o_index <= 'h19;     'h0E : o_index <= 'h20;     'h0F : o_index <= 'h28;

//            'h10 : o_index <= 'h21;     'h11 : o_index <= 'h1A;     'h12 : o_index <= 'h13;     'h13 : o_index <= 'h0C;
//            'h14 : o_index <= 'h05;     'h15 : o_index <= 'h06;     'h16 : o_index <= 'h0D;     'h17 : o_index <= 'h14;
//            'h18 : o_index <= 'h1B;     'h19 : o_index <= 'h22;     'h1A : o_index <= 'h29;     'h1B : o_index <= 'h30; 
//            'h1C : o_index <= 'h38;     'h1D : o_index <= 'h31;     'h1E : o_index <= 'h2A;     'h1F : o_index <= 'h23;
            
//            'h20 : o_index <= 'h1C;     'h21 : o_index <= 'h15;     'h22 : o_index <= 'h0E;     'h23 : o_index <= 'h07;
//            'h24 : o_index <= 'h0F;     'h25 : o_index <= 'h16;     'h26 : o_index <= 'h1D;     'h27 : o_index <= 'h24;
//            'h28 : o_index <= 'h2B;     'h29 : o_index <= 'h32;     'h2A : o_index <= 'h39;     'h2B : o_index <= 'h3A;
//            'h2C : o_index <= 'h33;     'h2D : o_index <= 'h2C;     'h2E : o_index <= 'h25;     'h2F : o_index <= 'h1E;

//            'h30 : o_index <= 'h17;     'h31 : o_index <= 'h1F;     'h32 : o_index <= 'h26;     'h33 : o_index <= 'h2D;
//            'h34 : o_index <= 'h34;     'h35 : o_index <= 'h3B;     'h36 : o_index <= 'h3C;     'h37 : o_index <= 'h35;
//            'h38 : o_index <= 'h2E;     'h39 : o_index <= 'h27;     'h3A : o_index <= 'h2F;     'h3B : o_index <= 'h36;
//            'h3C : o_index <= 'h3D;     'h3D : o_index <= 'h3E;     'h3E : o_index <= 'h37;     'h3F : o_index <= 'h3F;
//        endcase
//    end


//endmodule
