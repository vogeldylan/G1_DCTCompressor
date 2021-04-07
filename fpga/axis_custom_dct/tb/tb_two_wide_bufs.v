`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_two_wide_bufs
// Description:
//  Double and transpose buffer test benches
//
// Last Modified: 2021-03-01
//
//////////////////////////////////////////////////////////////////////////////////

module tb_two_wide_bufs #(
    parameter DATA_WIDTH = 8,       // pixel bit depth
    parameter ADDR_WIDTH = 6        // address width
)();


    // input signals
    reg clk, data_vld, resetn;
    reg [DATA_WIDTH-1 : 0] wdata0, wdata1;
    // output signals
    wire sync;
    wire [DATA_WIDTH-1 : 0] rdata0, rdata1;
    // test signals
    reg [7:0] tstcase;
    reg test_failed, failed;
    
    
    two_wide_transpose_buf #(DATA_WIDTH, ADDR_WIDTH)
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
        data_vld = 0;
        resetn = 0;
        wdata0 = 0;
        wdata1 = 0;
        tstcase = 0;
        failed = 0;
        test_failed = 0;    
    end
    
    // generate 
    always clk = #5 ~clk;
    
    always @(negedge clk) begin
        if (tstcase < 128 + 2) begin
            if (tstcase == 0) begin
                resetn <= 0;
            end
            else if (tstcase == 2) begin
                resetn <= 1;
                data_vld <= 1;
            end
            else if (tstcase == 66) begin
                data_vld <= 0;
            end
            
            wdata0 <= tstcase - 2;
            wdata1 <= tstcase - 2 + 1;
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
        #1 tstcase = tstcase + 2;
    end

endmodule