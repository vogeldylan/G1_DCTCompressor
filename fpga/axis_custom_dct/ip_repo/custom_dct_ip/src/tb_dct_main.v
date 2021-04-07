`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_dct_main
// Description:
//  DCT main test bench
//
// Last Modified: 2021-03-01
//
//////////////////////////////////////////////////////////////////////////////////

module tb_dct_main #(
    parameter DATA_WIDTH = 8,       // pixel bit depth
    parameter COEFF_WIDTH = 9,
    parameter FIRST_STAGE_WIDTH = 21,
//    parameter SECOND_STAGE_WIDTH = 33,
    parameter SECOND_STAGE_WIDTH = 25,
    parameter QUANT_STAGE_WIDTH = 14,
    parameter RUNL_STAGE_WIDTH = 16
)();


    // input signals
    reg clk, data_vld, resetn;
    reg [DATA_WIDTH-1 : 0] wdata0, wdata1;
    // output signals
    wire sync;
    wire [RUNL_STAGE_WIDTH-1 : 0] rdata0, rdata1;
    // test signals
    reg [15:0] tstcase;
    reg [7:0] num_iter;
    reg test_failed, failed, test_start;
    
    reg [7:0] test_data [0 : 63];
    initial begin
        $readmemh("dct_test_block.mem", test_data, 0, 63);
    end
    
    dct_main #(DATA_WIDTH, COEFF_WIDTH, FIRST_STAGE_WIDTH, SECOND_STAGE_WIDTH, QUANT_STAGE_WIDTH, RUNL_STAGE_WIDTH)
        DUT (
            .wdata0(wdata0),
            .wdata1(wdata1),
            .i_clk(clk),
            .wen(data_vld),
            .i_resetn(resetn),
            .rdata0(rdata0),
            .rdata1(rdata1),
            .rsync(sync)
            );
    
    initial begin
        clk = 0;
        data_vld = 1;
        wdata0 = 0;
        wdata1 = 0;
        tstcase = 0;
        failed = 0;
        test_failed = 0;
        test_start = 0;
        num_iter = 0;
    end
    
    // generate 
    always clk = #5 ~clk;
    
    // set resetn high
    initial begin
        resetn = 0;
        repeat (5) @(negedge clk);
        forever begin
            @(negedge clk) test_start <= 1;
            @(negedge clk) resetn <= 1'b1;
        end
    end
    
    always @(negedge clk) begin
        if (tstcase < 256) begin
            wdata0 <= test_data[(tstcase%64)];
            wdata1 <= test_data[(tstcase%64) + 1];
            
            if (sync) begin
                $display("Got back %0d, %0d: ", rdata0, rdata1); 
            end
        end
        
        // handle printing errors
        #1 if (failed) begin
            // would have been the previous testc case
            $display("ERORR: test case %0d failed", tstcase-1);
            failed <= 0;
            test_failed <= 1;
        end
        // increment the test case number
        if (test_start && resetn)
            #1 tstcase <= (tstcase + 2);;
    end

endmodule