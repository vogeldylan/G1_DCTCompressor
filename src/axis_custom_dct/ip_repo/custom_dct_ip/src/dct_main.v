`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: dct_main
// Description:
//  Coordinates the two 1D DCT stages and the transpose buffer
//
// Last Modified: 2021-03-22
//
//////////////////////////////////////////////////////////////////////////////////

module dct_main #(
    parameter DATA_WIDTH = 8,
    // parameter ADDR_WIDTH = 6,
    parameter COEFF_WIDTH = 9,
    parameter FIRST_STAGE_WIDTH = 21,
    parameter SECOND_STAGE_WIDTH = 25,
    parameter QUANT_STAGE_WIDTH = 14,
    parameter RUNL_STAGE_WIDTH = 16
)(
    input i_clk,
    input i_resetn,                      // active-low reset

    // writing to this block
    input [DATA_WIDTH-1 : 0] wdata0, wdata1,
    input wen,  // write enable

    // reading from this block
    output [RUNL_STAGE_WIDTH-1 : 0] rdata0, rdata1,
    output rsync // tell the output that we're 
);
    
    localparam ADDR_WIDTH = 6; // this is fixed

    // reset and valid signal for the 1D stages
    // reg resetn;
    // sync and valid signal from the 1D stages
    wire f_stage_ivld, f_stage_osync, s_stage_osync, f_stage_ovld, s_stage_ovld, s_stage_ivld;
    wire q_stage_osync, zz_stage_osync, rl_stage_osync;

    // inputs to first stage
    wire [DATA_WIDTH-1 : 0] f_stage_p0, f_stage_p1;
    // outputs from first stage
    wire [FIRST_STAGE_WIDTH-1 : 0] f_stage_c0, f_stage_c1;
    // inputs to second stage
    wire [FIRST_STAGE_WIDTH-1 : 0] s_stage_p0, s_stage_p1;
    // outputs from second stage
    wire [SECOND_STAGE_WIDTH-1 : 0] s_stage_c0, s_stage_c1;
    // outpus from the quantization stage
    wire [QUANT_STAGE_WIDTH-1 : 0] q_stage_q0, q_stage_q1;
    // outputs from the zig-zag stage
    wire [QUANT_STAGE_WIDTH-1 : 0] zz_stage_c0, zz_stage_c1;
    // outputs from the run-length encoder
    wire [RUNL_STAGE_WIDTH-1 : 0] rl_stage_c0, rl_stage_c1;
    
    // assign the outputs
    // eventually will be the output of the run-length stage
//    assign rdata0 = q_stage_q0;
//    assign rdata1 = q_stage_q1;
//    assign rsync = q_stage_osync;
    assign rdata0 = rl_stage_c0;
    assign rdata1 = rl_stage_c1;
    assign rsync = rl_stage_osync;
    
    // assign the inputs
    assign f_stage_p0 = wdata0;
    assign f_stage_p1 = wdata1;
    assign f_stage_ivld = wen;

    // init the first stage, performing DCT row operations  
    dct_stage #(DATA_WIDTH, FIRST_STAGE_WIDTH, COEFF_WIDTH, 1) 
        dct_row(  
            // inputs
            .i_p0(f_stage_p0),
            .i_p1(f_stage_p1),
            .i_clk(i_clk), 
            .i_resetn(i_resetn), 
            .i_vld(f_stage_ivld), 
            // outputs
            .o_c0(f_stage_c0),
            .o_c1(f_stage_c1),
            .o_sync(f_stage_osync));

    // instantantiate the transpose buffer
    // TODO: check this
	two_wide_transpose_buf #(FIRST_STAGE_WIDTH, ADDR_WIDTH)
        transpose_buf(
            .i_clk(i_clk),
            .i_resetn(i_resetn),
            .wdata0(f_stage_c0),
            .wdata1(f_stage_c1),
            .wen(f_stage_osync),
            .rdata0(s_stage_p0),
            .rdata1(s_stage_p1),
            .rsync(s_stage_ivld)
            );

    // init the second stage, performing DCT column operations
    dct_stage #(FIRST_STAGE_WIDTH, SECOND_STAGE_WIDTH, COEFF_WIDTH, 0) 
        dct_col(  
            // inputs
            .i_p0(s_stage_p0),
            .i_p1(s_stage_p1),
            .i_clk(i_clk), 
            .i_resetn(i_resetn), 
            .i_vld(s_stage_ivld), 
            // outputs
            .o_c0(s_stage_c0),
            .o_c1(s_stage_c1),
            .o_sync(s_stage_osync));

    // init the output quantization stage
    quant_stage #(SECOND_STAGE_WIDTH, QUANT_STAGE_WIDTH)
        quant(
            // inputs
            .i_c0(s_stage_c0),
            .i_c1(s_stage_c1),
            .i_clk(i_clk),
            .i_resetn(i_resetn),
            .i_vld(s_stage_osync),
            //outputs
            .o_q0(q_stage_q0),
            .o_q1(q_stage_q1),
            .o_sync(q_stage_osync));

    zig_zag_stage #(QUANT_STAGE_WIDTH, 6)
        zz_stage(
            .i_clk(i_clk),
            .i_resetn(i_resetn),
            .wdata0(q_stage_q0), 
            .wdata1(q_stage_q1),
            .wen(q_stage_osync),
            .rdata0(zz_stage_c0),
            .rdata1(zz_stage_c1),
            .rsync(zz_stage_osync));

    run_length_stage #(QUANT_STAGE_WIDTH, RUNL_STAGE_WIDTH)
        rl_stage(
            .i_clk(i_clk),
            .i_resetn(i_resetn),
            .i_data0(zz_stage_c0),
            .i_data1(zz_stage_c1),
            .wen(zz_stage_osync),
            .o_data0(rl_stage_c0),
            .o_data1(rl_stage_c1),
            .rsync(rl_stage_osync)
        );
    

    // comment out for the time being    
    // // async fifo so that the run-length stage can be clocked faster
    // fifo_generator_0 rl_fifo(
    //         .rst(i_resetn),
    //         .wr_clk(i_clk),
    //         .rd_clk(),
    //         .din(q_stage_dbl),
    //         .wr_en(q_stage_osync),
    //         .rd_en(),
    //         .dout(),
    //         .full(),
    //         .almost_full(),
    //         .empty());
    
   
    // end of DCT main

endmodule
