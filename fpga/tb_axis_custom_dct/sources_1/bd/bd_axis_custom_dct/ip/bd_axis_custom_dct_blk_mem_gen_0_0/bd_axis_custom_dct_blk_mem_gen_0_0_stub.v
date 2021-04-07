// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Tue Mar 23 16:34:56 2021
// Host        : BIRD-NEST running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               D:/xilinx-projects/ECE532/HealthVivado/custom_dct/tb_axis_custom_dct/tb_axis_custom_dct.srcs/sources_1/bd/bd_axis_custom_dct/ip/bd_axis_custom_dct_blk_mem_gen_0_0/bd_axis_custom_dct_blk_mem_gen_0_0_stub.v
// Design      : bd_axis_custom_dct_blk_mem_gen_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_2,Vivado 2018.3" *)
module bd_axis_custom_dct_blk_mem_gen_0_0(clka, rsta, ena, wea, addra, dina, douta, rsta_busy)
/* synthesis syn_black_box black_box_pad_pin="clka,rsta,ena,wea[3:0],addra[31:0],dina[31:0],douta[31:0],rsta_busy" */;
  input clka;
  input rsta;
  input ena;
  input [3:0]wea;
  input [31:0]addra;
  input [31:0]dina;
  output [31:0]douta;
  output rsta_busy;
endmodule
