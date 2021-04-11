`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: dct_stage
// Description:
//  Single 1-D DCT stage. Feed it some pixels and get coeffs out (hopefully)
//
// Last Modified: 2021-03-16
//
//////////////////////////////////////////////////////////////////////////////////

module dct_stage #(
    parameter DATA_WIDTH = 8,       // pixel bit depth
    parameter OUTPUT_WIDTH = 12,    // output coefficient width
    parameter COEFF_WIDTH = 9,      // coefficient bit width
    parameter INPUT_SHIFT = 0       // whether to shift the input
) (
//    old 
//    input [DATA_WIDTH-1 : 0] i_p0, i_p1, i_p2, i_p3, i_p4, i_p5, i_p6, i_p7,    // input pixel stream
    input signed [DATA_WIDTH-1 : 0] i_p0, i_p1, // input pixel stream

    input i_clk,                   // input clock
    input i_vld,                   // signal indicating that the input is valid
    input i_resetn,                // reset signal
//    old
//    output signed [OUTPUT_WIDTH-1 : 0] o_c0, o_c1, o_c2, o_c3, o_c4, o_c5, o_c6, o_c7,

    output signed [OUTPUT_WIDTH-1 : 0] o_c0, o_c1,
    
    output o_sync                 // sync signal indicating that new data can be input
//    old
//    output o_vld                   // signal indicating that the output is valid
);

    // register definitions

    reg [2 : 0] n_in, n_out, n_mult;            // indicate the number of inputs, outputs, and mults
    reg addsum_vld, olatch_vld, olatch_rdy, r_o_sync;       // indicate whether we've latched addsum

    reg signed [DATA_WIDTH : 0] i_latch [0:7];                // shifted input latch
    reg signed [DATA_WIDTH : 0] addsub [0:7];                   // additions and subtractions
    reg signed [DATA_WIDTH+COEFF_WIDTH+3 : 0] mult [0:7];    // multiplies
    reg signed [DATA_WIDTH+COEFF_WIDTH+3 : 0] acc [0:7];     // accumulates
    reg signed [DATA_WIDTH+COEFF_WIDTH+3 : 0] o_latch [0:7];    // output latches
    reg signed [DATA_WIDTH+COEFF_WIDTH+3 : 0] r_oc0, r_oc1;     // output buffers 

    reg signed [COEFF_WIDTH-1 : 0] ram_coeff [0 : 31];   // 16 matrix coefficients
    initial begin
        $readmemh("ram_coeff.mem", ram_coeff, 0, 31);
    end

    // assign the output signals
    assign o_sync = r_o_sync;

    // shift the input pixel values
//    assign i_pshift[0] = i_p0 - 127;
//    assign i_pshift[1] = i_p1 - 127;
//    assign i_pshift[2] = i_p2 - 127;
//    assign i_pshift[3] = i_p3 - 127;
//    assign i_pshift[4] = i_p4 - 127;
//    assign i_pshift[5] = i_p5 - 127;
//    assign i_pshift[6] = i_p6 - 127;
//    assign i_pshift[7] = i_p7 - 127;

    // output latches, plus bus width shifting
    assign o_c0 = r_oc0[DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
    assign o_c1 = r_oc1[DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
    
//    assign o_c2 = r_out[2][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
//    assign o_c3 = r_out[3][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
//    assign o_c4 = r_out[4][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
//    assign o_c5 = r_out[5][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
//    assign o_c6 = r_out[6][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];
//    assign o_c7 = r_out[7][DATA_WIDTH + COEFF_WIDTH + 3  :  DATA_WIDTH + COEFF_WIDTH + 3 - (OUTPUT_WIDTH - 1)];

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
            if (i_vld && n_in < 4) begin
                // if we're not done latching keep counting
                n_in <= n_in + 1;
            end
            else if (i_vld && n_in == 4) begin
                // if we're done latching, get ready to loop
                n_in <= 1;
            end
            else if (~i_vld && n_in == 4) begin
                // go back to zero if the input isn't currently valid
                n_in <= 0;
            end
            else begin
                // hold the value constant
                n_in <= n_in;
            end
        end
    end
    
    
    // handle the input latches i_latch
    // i_latch should take every two inputs and latch them for use later
    integer a;
    initial begin
        for (a=0; a < 8; a=a+1) i_latch[a] = 0;
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            for (a=0; a < 8; a=a+1) begin
                i_latch[a] <= 0;
            end
        end
        else begin
            if (i_vld && n_in != 4) begin
                // if the input is valid, latch the input depending on the state of n_mult
                if (INPUT_SHIFT) begin
                    i_latch[2*n_in + 0] <= i_p0 - 2**(DATA_WIDTH-1);
                    i_latch[2*n_in + 1] <= i_p1 - 2**(DATA_WIDTH-1);
                end
                else begin
                    i_latch[2*n_in + 0] <= i_p0;
                    i_latch[2*n_in + 1] <= i_p1;
                end                  
            end
            else if (i_vld && n_in == 4) begin
                // done latching, go back to the first two
                if (INPUT_SHIFT) begin
                    i_latch[0] <= i_p0 - 2**(DATA_WIDTH-1);
                    i_latch[1] <= i_p1 - 2**(DATA_WIDTH-1);
                end
                else begin
                    i_latch[0] <= i_p0;
                    i_latch[1] <= i_p1;
                end
            end
        end
    end    


    // handle addsum_vld
    // addsum_vld tell the multpliers that we're ready
    // addsum_vld should go high when a valid set of adds and subtracts are latched
    // into the corresponding registers.
    initial addsum_vld = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // no longer valid
            addsum_vld <= 0;
        end
        else begin
            if (~addsum_vld && n_in == 4) begin
                // if we're not already valid and n_in is done, we're valid
                addsum_vld <= 1; 
            end
            else if(addsum_vld && n_mult == 3 && n_in != 4) begin
                // if we're done multiplying but an input is not ready to add/subtract, clear addsum
                addsum_vld <= 0;
            end
            else begin
                // hold steady
                addsum_vld <= addsum_vld;
            end            
        end
    end
    

    // handle the addsub memory
    // addsub should be computed if we're ready to accept input and the input is valid
    integer i;
    initial begin
        for (i=0; i<8; i=i+1) addsub[i] =0;
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin 
            // reset the array
            for (i=0; i < 8; i=i+1) begin
                addsub[i] <= 0;
            end
        end
        else begin
            if (n_in == 4) begin
                // if we're done latching input, add and subtract
                for (i=0; i < 4; i=i+1) begin
                    addsub[i] <= i_latch[i] + i_latch[7-i];
                    addsub[4+i] <= i_latch[i] - i_latch[7-i]; 
                end
            end
            else begin
                // hold the value constant
                for (i=0; i < 8; i=i+1) begin
                    addsub[i] <= addsub[i];
                end
            end            
        end
    end


    // handle n_mult
    // this signal just tracks how many times we've multiplied
    initial n_mult = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset
            n_mult <= 0;
        end
        else begin
            if (addsum_vld && n_mult < 4) begin
                // adds and subtracts are valid, increment
                n_mult <= n_mult + 1;
            end
            else if (addsum_vld && n_mult == 4) begin
                // done multiplying, still valid, go back to 1
                n_mult <= 1;
            end
            else begin
                // adds and subtracts not valid, or became valid and somehow n_mult > 4
                n_mult <= 0;
            end            
        end
    end


    // handle the mults
    // if addsum is valid we should multiply and accumulate
    // if n_mult == 0 or n_mult == 4 we should reset the accumulator
    integer j;
    initial begin
        for(j=0; j<8; j=j+1) begin
            mult[j] = 0;
        end
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the array
            for (j=0; j < 8; j=j+1) begin
                mult[j] <= 0;
            end
        end
        else begin
            if (addsum_vld && (n_mult == 0 || n_mult == 4)) begin
                // reset the accumulators and calc the new value
                for (j=0; j < 4; j=j+1) begin
                    // lower half
                    mult[j] <= ram_coeff[4*j] * addsub[0];
                    // upper half
                    mult[j+4] <= ram_coeff[4*(j+4)] * addsub[4];
                end
            end
            else if (addsum_vld && ~(n_mult == 0 || n_mult == 4)) begin
                // normal cycle, multiply and accumulate
                for (j=0; j < 4; j=j+1) begin
                    mult[j] <= ram_coeff[4*j + n_mult] * addsub[n_mult];
                    mult[j+4] <= ram_coeff[4*(j+4) + n_mult] * addsub[n_mult + 4];
                end
            end
        end
    end
    
    integer b;
    initial begin
        for(b=0; b<8; b=b+1) begin
            acc[b] = 0;
        end
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the array
            for (j=0; j < 8; j=j+1) begin
                acc[j] <= 0;
            end
        end
        else begin
            if (addsum_vld && n_mult == 1) begin
                // reset the accumulators and calc the new value
                for (j=0; j < 8; j=j+1) begin
                    acc[j] <= mult[j];
                end
            end
            else if (addsum_vld && !(n_mult == 1)) begin
                // normal cycle, multiply and accumulate
                for (j=0; j < 8; j=j+1) begin
                    acc[j] <= acc[j] + mult[j];
                end
            end
        end
    end
        
    // handle olatch_rdy
    // olatch_rdy should go high when there is a valid multiply
    initial olatch_rdy = 0;
    always @(posedge i_clk) begin
        if (!i_resetn) begin
            // reset the output latch
            olatch_rdy <= 0;
        end
        else begin
            if (~olatch_rdy && n_mult == 4) begin
                // we're latching the output
                olatch_rdy <= 1;
            end
            else if (olatch_rdy && n_out == 2 && n_mult != 4) begin
                // if we're done latching but not ready to re-latch, reset
                olatch_rdy <= 0;
            end
            else begin
                olatch_rdy <= olatch_rdy;
            end
        end
    end
    
    // handle olatch_vld
    // should go high when there is a valid accumulate
    initial olatch_vld = 0;
    always @(posedge i_clk) begin
        if (!i_resetn) 
            olatch_vld <= 0;
        else 
            olatch_vld <= olatch_rdy;
     end
     
    // handle the output latching
    integer k;
    initial begin
        for(k=0; k<8; k=k+1) o_latch[k] =0;
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin
           for (k=0; k < 8; k=k+1 ) begin
               // reset the output registers
               o_latch[k] <= 0;
           end 
        end
        else begin
            if (n_mult == 1) begin
                // done the required number of multiplies and accumulates, latch the output
                for (k=0; k < 4; k=k+1) begin
                    // need to alternate even and odd coefficients
                    o_latch[2*k]     <= acc[k];
                    o_latch[2*k + 1] <= acc[4 + k];
                end
            end
            else begin
                // hold the value
                for (k=0; k < 8; k=k+1 ) begin
                    // reset the output registers
                    o_latch[k] <= o_latch[k];
                end                 
            end
        end
    end
    
    
    // handle n_out
    // n_out should increment as long as we have some valid output latched
    // n_out should wrap if we get new output ready
    initial n_out = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            n_out <= 0;
        end 
        else begin
            if (olatch_vld && n_out < 4) begin
                // latched output valid, keep counting
                n_out <= n_out + 1;
            end
            else if (olatch_vld && n_out == 4) begin
                // if we're done latching, get ready to loop
                n_out <= 1;
            end
            else begin
                // in any other case just reset
                n_out <= 0;
            end
        end
    end
    
    
    // handle r_oc0 and r_oc1
    // the absolute accuracy of these don't matter since we have o_sync to indicate output is ready
    initial r_oc0 = 0;
    initial r_oc1 = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            r_oc0 <= 0;
            r_oc1 <= 0;
        end
        else begin
            if (n_out != 4) begin
                // always latch the output depending on the state of n_out
                r_oc0 <= o_latch[2*n_out + 0];
                r_oc1 <= o_latch[2*n_out + 1];
            end
            else if (n_out == 4) begin
                // done shifting, go back to the first two
                r_oc0 <= o_latch[0];
                r_oc1 <= o_latch[1];
            end
        end
    end
    
    
    // handle the output sync signal
    // this signal should go high at the 
    // the master can also just latch new data once o_sync goes low, saving some time
    initial r_o_sync = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // no valid output
            r_o_sync <= 0;
        end
        else begin
            if (olatch_vld) begin
                // if olatch_vld is high (on this cycle) set o_sync high
                r_o_sync <= 1;
            end
            else begin
                // otherwise the output isn't valid
                r_o_sync <= 0;
            end            
        end
    end

    
endmodule