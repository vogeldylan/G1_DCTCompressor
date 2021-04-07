`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: custom_dct_axis
// Description:
//  interfaces the custom DCT block to axistream
//
// Last Modified: 2021-03-23
//
//////////////////////////////////////////////////////////////////////////////////


module custom_dct_axis #(
    // AXI STREAM PARAMETERS
    parameter C_AXIS_TDATA_WIDTH = 16, // another illusion of choice

    // DCT PARAMETERS
    parameter DATA_WIDTH = 8,
    parameter COEFF_WIDTH = 9,
    parameter FIRST_STAGE_WIDTH = 21,
    parameter SECOND_STAGE_WIDTH = 25,
    parameter QUANT_STAGE_WIDTH = 14,
    parameter RUNL_STAGE_WIDTH = 16 // an illusion of choice
)(
    // common signals 
    input  wire                                 aclk,
    input  wire                                 aresetn,
    
    // Slave interface for DCT input
    input  wire [C_AXIS_TDATA_WIDTH-1:0]        s_axis_tdata,
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1 : 0]  s_axis_tstrb,
    input  wire                                 s_axis_tvalid,
    output wire                                 s_axis_tready,
    input  wire                                 s_axis_tlast,
    
    // Master interface for DCT output
    output wire [RUNL_STAGE_WIDTH*2 - 1:0]        m_axis_tdata,
    output wire [(RUNL_STAGE_WIDTH/4)-1 : 0]  m_axis_tstrb, // normall /8 but *2
    output wire                                 m_axis_tvalid,
    input  wire                                 m_axis_tready,
    output wire                                 m_axis_tlast
    
    );
    localparam ADDR_WIDTH = 6;
    
    // put data in, get data out
    reg [DATA_WIDTH - 1 : 0] i_data0, i_data1;
    wire [RUNL_STAGE_WIDTH - 1 : 0] o_data0, o_data1;
    wire [RUNL_STAGE_WIDTH*2 - 1 : 0] o_dbl; // for storing both outputs to fifo
    wire [RUNL_STAGE_WIDTH*2 - 1 : 0] o_fifo; // for output of the fifo, can be transmit over stream
    reg [RUNL_STAGE_WIDTH*2 - 1 : 0] m_axis_tdata_reg; // for buffering the output

    wire i_sync; // used to synchronize when the DCT block reads the input
    wire o_sync; // used to synchronize when the output should be written out
    wire fifo_rden; // used to enable reads from the fifo
    wire fifo_empty, fifo_full, fifo_rst; // fifo signals
    reg m_axis_tvalid_reg, m_axis_tvalid_rdy;
    
    // used to count how many packets we should handle    
    reg [31 : 0] n_pixel_in;
    wire [25 : 0] n_block_in;
    reg [25 : 0] n_block_out;
    reg[16 : 0] n_block_diff;
    reg m_axis_tlast_reg; // used to indicate the end of a packet

    // this essentially counts the number of 64-pixel blocks that we input I think
    // 64 is 2^6
    assign n_block_in = n_pixel_in[31 : 6];

    /* PACKET COUNTING */
    
    // this is janky because the clocks need to be the same. Hence, need big fifo
    initial n_pixel_in = 0;
    always @(posedge aclk) begin
        if (!aresetn) begin
            n_pixel_in <= 0;
        end
        else begin
            if (i_sync)
                // we input two 
                n_pixel_in <= n_pixel_in + 2;
        end
    end
    
    // the EOF in our scheme is all 1's
    localparam EOF = {RUNL_STAGE_WIDTH{1'b1}};
    
    initial n_block_out = 0;
    always @(posedge aclk) begin
        if (!aresetn) begin
            n_block_out <= 0;
        end
        else begin  
            if (m_axis_tvalid && m_axis_tready && (m_axis_tdata[31:16]==EOF || m_axis_tdata[15:0]==EOF))
                // both TX and RX accept the packet, one of the datas is the EOF
                n_block_out <= n_block_out + 1; 
        end
    end
    
    initial n_block_diff = 0;
    always @(posedge aclk) begin
        if(!aresetn) begin
            n_block_diff <= 0;
        end
        else begin
            // the number of blocks different is the number of blocks in minus out
            n_block_diff <= n_block_in - n_block_out;
        end
    end    
      
    // handle the tlast output
    // since packet_diff is disabled, this is disabled
    initial m_axis_tlast_reg = 0;
    always @(posedge aclk) begin
        if(!aresetn) begin
            // reset tlast
            m_axis_tlast_reg <= 0;
        end
        else begin
            if (n_block_diff == 1 && (!i_sync && (m_axis_tvalid & m_axis_tready)))
                // last packet, not inputting, but outputting. Hence, last packet
                m_axis_tlast_reg <= 1;
            else
                // otherwise, should be zero
                m_axis_tlast_reg <= 0;
        end
    end


    /* SLAVE INTERFACE */
    // assume that we reset from the slave I guess


    // we are always ready to accept input
    assign s_axis_tready = 1;
    // if there is valid data then we write to the DCT block
    assign i_sync = s_axis_tready && s_axis_tvalid;

    // handle writing to inbufs
    always @(posedge aclk) begin
        if (~aresetn) begin
            // reset the inputs
            i_data0 <= 0;
            i_data1 <= 0;
        end
        else begin
            // TODO: figure out if this is correct **************
            // might be the other way around for byte ordering
            i_data0 <= s_axis_tdata[7 : 0];
            i_data1 <= s_axis_tdata[15: 8];
        end
    end


    // instantantiate the dct main block
    dct_main #(DATA_WIDTH, COEFF_WIDTH, FIRST_STAGE_WIDTH, SECOND_STAGE_WIDTH)
        dct_main(
            .i_clk(aclk),
            .i_resetn(aresetn),
            .wdata0(i_data0),
            .wdata1(i_data1),
            .wen(i_sync),
            .rdata0(o_data0),
            .rdata1(o_data1),
            .rsync(o_sync)
            );

    
    assign o_dbl = {o_data1, o_data0}; // for input to the fifo

    // fifo reset is not aresetn
    assign fifo_rst = !aresetn;

    // instantantiate the outptut fifo
    // also needs to be 32-bit wide now
    fifo_generator_1 axis_fifo(
        .clk(aclk),
        .rst(fifo_rst),
        .din(o_dbl),
        .wr_en(o_sync),
        .rd_en(fifo_rden),
        .dout(o_fifo),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    /* MASTER INTERFACE */

    // the output strobe should always be high
    assign m_axis_tstrb = 4'b1111;
    assign m_axis_tlast = m_axis_tlast_reg; // should signal EOP when EOP????

    // to read from the fifo, either we must currently have no valid data, or we're about to latch out the data
    // and, we must also have that the fifo is not empty.
    assign fifo_rden = (!m_axis_tvalid || (m_axis_tvalid && m_axis_tready)) && !fifo_empty;
    // set the signal equal to it's register
    assign m_axis_tvalid = m_axis_tvalid_reg;

    // handle switching tvalid_rdy
    // tvalid_rdy should go high if we're about to read valid data, and go low if we latch out the data and don't have new stuff
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid_rdy <= 0;
        end
        else begin
            if (!m_axis_tvalid && fifo_rden)
                m_axis_tvalid_rdy <= 1; // we're about to read good data
            else if (m_axis_tvalid && m_axis_tready && !fifo_rden)
                m_axis_tvalid_rdy <= 0; // we've latched out the data but nothing new is ready
            else if (m_axis_tvalid && m_axis_tready && fifo_rden)
                m_axis_tvalid_rdy <= 1; // just to be explicit    end
        end
    end
    
    // handle switching tvalid
    // tvalid should follow tvalid rdy
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid_reg <= 0;
        end
        else begin
            m_axis_tvalid_reg <= m_axis_tvalid_rdy;
        end
    end
    
    // assign the stream output to the register
    assign m_axis_tdata = m_axis_tdata_reg;
    // latch the output of the fifo if we're reading
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tdata_reg <= 0; // no valid data
        end
        else begin
            if (m_axis_tvalid_rdy)
                m_axis_tdata_reg <= o_fifo; // transfer the fifo output to the output register
        end
    end

endmodule


