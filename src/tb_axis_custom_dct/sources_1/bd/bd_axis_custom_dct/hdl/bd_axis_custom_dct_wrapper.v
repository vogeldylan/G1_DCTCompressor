//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Mon Mar 29 20:43:29 2021
//Host        : BIRD-NEST running 64-bit major release  (build 9200)
//Command     : generate_target bd_axis_custom_dct_wrapper.bd
//Design      : bd_axis_custom_dct_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module bd_axis_custom_dct_wrapper
   (aclk,
    aresetn);
  input aclk;
  input aresetn;

  wire aclk;
  wire aresetn;

  bd_axis_custom_dct bd_axis_custom_dct_i
       (.aclk(aclk),
        .aresetn(aresetn));
endmodule
