`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_dct_stage
// Description:
//  Single 1-D DCT stage testbench
//
// Last Modified: 2021-03-01
//
//////////////////////////////////////////////////////////////////////////////////

module tb_dct_stage #(
    parameter DATA_WIDTH = 8,       // pixel bit depth
    parameter OUTPUT_WIDTH = 12,    // output coefficient width
    parameter COEFF_WIDTH = 12      // coefficient bit width
)(
);


// input signals
reg clk, data_vld, resetn;
reg [DATA_WIDTH-1 : 0] p0, p1;
// output signals
wire sync;
wire [OUTPUT_WIDTH-1 : 0] c0, c1;
// test signals
reg [7:0] tstcase;
reg test_failed, failed;


dct_stage #(DATA_WIDTH, OUTPUT_WIDTH, COEFF_WIDTH)
    DUT (
        .i_p0(p0),
        .i_p1(p1),
        .i_clk(clk),
        .i_vld(data_vld),
        .i_resetn(resetn),
        .o_c0(c0),
        .o_c1(c1),
        .o_sync(sync)
        );

initial begin
    clk = 0;
    data_vld = 0;
    resetn = 0;
    p0 = 0;
    p1 = 0;
    tstcase = 0;
    failed = 0;
    test_failed = 0;    
end

// generate 
always clk = #5 ~clk;

always @(negedge clk) begin
    case(tstcase)
        0 : begin
            resetn <= 0;
        end
        1 : begin
            resetn <= 1;
            data_vld <= 1;
            p0 <= 1;
            p1 <= 2;
        end
        2 : begin
            p0 <= 3;
            p1 <= 4;
        end
        3 : begin
            p0 <= 5;
            p1 <= 6;
        end
        4 : begin
            p0 <= 7;
            p1 <= 8;
        end
        default : begin
            $display("waiting ...");
        end
    endcase
    
    
    // handle printing errors
    #1 if (failed) begin
        // would have been the previous testc case
        $display("ERORR: test case %0d failed", tstcase-1);
        failed <= 0;
        test_failed <= 1;
    end
    // increment the test case number
    #1 tstcase = tstcase + 1;
end

endmodule