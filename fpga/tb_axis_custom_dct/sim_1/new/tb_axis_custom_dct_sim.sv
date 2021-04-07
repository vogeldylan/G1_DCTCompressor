`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_axis_custom_dct_sim
// Description:
//  simulate the AXI interface to the custom DCT block
//
// Last Modified: 2021-03-23
//
//////////////////////////////////////////////////////////////////////////////////

// include the master testbench
`include "tb_axis_custom_dct_mst.sv" 

module tb_axis_custom_dct_sim(
    ); // no inputs
    
    reg clk, resetn;
    
    // instantiate block diagram
    bd_axis_custom_dct_wrapper DUT(
        .aresetn(resetn),
        .aclk(clk)
    );
    
    initial begin
        clk = 0;
        forever 
            clk = #5 ~clk;
    end
    
    // set resetn high
    initial begin
        resetn = 0;
        repeat (5) @(posedge clk);
        forever 
            @(posedge clk) resetn <= 1'b1;
    end
    
    // instantiate the master axi vip
    axis_vip_0_mst_stimulus mst();
    
endmodule