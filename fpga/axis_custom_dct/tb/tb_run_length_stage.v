`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_run_length_stage
// Description:
//  run-length stage test bench
//
// Last Modified: 2021-03-28
//
//////////////////////////////////////////////////////////////////////////////////

module tb_run_length_stage #(
    parameter DATA_WIDTH = 15,
    parameter OUTPUT_WIDTH = 16
)();

    // input signals
    reg clk, data_vld, resetn;
    reg [DATA_WIDTH-1 : 0] wdata0, wdata1;
    // output signals
    wire sync;
    wire [DATA_WIDTH-1 : 0] rdata0, rdata1;
    // test signals
    reg [15:0] tstcase;
    reg [7:0] num_iter;
    reg test_failed, failed, test_start;
    
    reg [14:0] test_data [0 : 63];
    initial begin
        $readmemh("rl_test_block.mem", test_data, 0, 63);
    end
    
    run_length_stage #(DATA_WIDTH, OUTPUT_WIDTH)
        DUT (
            .i_clk(clk),
            .i_resetn(resetn),
            .i_data0(wdata0),
            .i_data1(wdata1),
            .wen(data_vld),
            .o_data0(rdata0),
            .o_data1(rdata1),
            .rsync(sync)
            );
    
    initial begin
        clk = 0;
//        data_vld = 1;
        wdata0 = 0;
        wdata1 = 0;
//        tstcase = 0;
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
        tstcase = 0;
        data_vld = 0;
        repeat (1) @(negedge clk);
        resetn = 1;
        repeat (10) @(negedge clk); // let the FIFO startup?????
        tstcase = 0; // set tstcase back to zero
        data_vld = 1; // set data now valid
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
            #1 tstcase <= (tstcase + 2);
    end

endmodule
