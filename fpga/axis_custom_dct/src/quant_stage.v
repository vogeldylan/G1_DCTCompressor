`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
//
// Module Name: quant_stage
// Description:
//  Quantization Stage
//  Assumes you're feeding in transposed DCT coefficients and performs quantization
//
// Last Modified: 2021-03-16
//
//////////////////////////////////////////////////////////////////////////////////

module quant_stage #(
    parameter DATA_WIDTH = 25,       // pixel bit depth
    parameter OUTPUT_WIDTH = 12       // output coefficient width
) (
    input signed [DATA_WIDTH-1 : 0] i_c0, i_c1, // input coefficient stream

    input i_clk,                   // input clock
    input i_vld,                   // signal indicating that the input is valid
    input i_resetn,                // reset signal

    output signed [OUTPUT_WIDTH-1 : 0] o_q0, o_q1,

    output o_sync                 // sync signal indicating that new data can be input
);
    localparam EXTRA_QUANT = 15; // to correct for the fixed-point arithmetic we've done
    localparam CORR_SHIFT = DATA_WIDTH-3-1-EXTRA_QUANT-(OUTPUT_WIDTH-1); // how much extra we need to shift the output by to properly cast into the output

    // register definitions

    reg [8 : 0] n_in;                           // indicate the number of inputs, outputs, and mults
    reg addsum_vld, olatch_vld, r_o_sync;       // indicate whether we've latched addsum

    // three is the minimum quantization value
    reg signed [DATA_WIDTH-3-1-EXTRA_QUANT-CORR_SHIFT : 0] r_oq0;
    reg signed [DATA_WIDTH-3-1-EXTRA_QUANT-CORR_SHIFT : 0] r_oq1;     // output buffers

    reg signed [7 : 0] quant_coeff [0 : 63];   // 16 matrix coefficients
    initial begin
        $readmemh("quant_coeff.mem", quant_coeff, 0, 63);
    end

    // assign the output signals
    assign o_sync = r_o_sync;

    // assign the output to be the 8 upper bits of the quantized values
    assign o_q0 = r_oq0;
    assign o_q1 = r_oq1;
//    assign o_q0 = r_oq0[DATA_WIDTH-3-1-EXTRA_QUANT  : DATA_WIDTH-3-1-EXTRA_QUANT-(OUTPUT_WIDTH-1)];
//    assign o_q1 = r_oq1[DATA_WIDTH-3-1-EXTRA_QUANT  : DATA_WIDTH-3-1-EXTRA_QUANT-(OUTPUT_WIDTH-1)];

    // handle n_in
    // n_in tracks how many inputs we've latched
    // n_in should increment or wrap every clock edge that in_vld is high
    initial n_in = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the count
            n_in <= 0;
        end
        else begin
            if (i_vld) begin
                // count n_in up and wrap at 64
                n_in <= (n_in + 2) % 64;
            end
            else begin
                // otherwise hold steady
                n_in <= n_in;
            end
        end
    end

    // handle r_oq0 and r_oq1
    // the absolute accuracy of these don't matter since we have o_sync to indicate output is ready
    initial r_oq0 = 0;
    initial r_oq1 = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            r_oq0 <= 0;
            r_oq1 <= 0;
        end
        else begin
            // o_sync handles whether the output is "valid"
            r_oq0 <= i_c0 >>> (quant_coeff[n_in] + EXTRA_QUANT + CORR_SHIFT);
            r_oq1 <= i_c1 >>> (quant_coeff[n_in + 1] + EXTRA_QUANT + CORR_SHIFT);
        end
    end


    // handle the output sync signal
    // this signal should go high when the input is valid
    initial r_o_sync = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // no valid output
            r_o_sync <= 0;
        end
        else begin
            if (i_vld) begin
                // if the input is valid (on this cycle) then the output will be on the next
                r_o_sync <= 1;
            end
            else begin
                // otherwise the output will not be "valid"
                // we only go valid for one cycle per input cycle, to properly pipeline the next block
                r_o_sync <= 0;
            end
        end
    end

endmodule