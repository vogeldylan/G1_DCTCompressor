`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: two_wide_double_buf
// Description:
//  2-port double buffer
//  The writer can control the block. Once a block is written it's assumed that
//  the reader will accept one set of read data per clock cycle
//
// Last Modified: 2021-03-01
//
//////////////////////////////////////////////////////////////////////////////////


module two_wide_double_buf #(
    DATA_WIDTH = 8,
    ADDR_WIDTH = 6
)(
    input i_clk,
    input i_resetn,
    // to avoid conflicts we write two values at once at sequential addresses
    input [DATA_WIDTH-1 : 0] wdata0, wdata1,
    // input [ADDR_WIDTH-1 : 0] waddr,
    input wen,
    // output wsync, // sync the writer writes

    // reading
    output [DATA_WIDTH-1 : 0] rdata0, rdata1,
    // output [ADDR_WIDTH-1 : 0] raddr,
    output reg rsync // sync the reader reads

    );

    // create internal signals
    // double buffer
    reg [DATA_WIDTH-1 : 0] ram_buf [0: 1] [0 : 2**ADDR_WIDTH - 1];
    // output buffers
    reg [DATA_WIDTH-1 : 0] reg_rdata0, reg_rdata1;
    // internal waddr and raddr
    reg [ADDR_WIDTH-1 : 0] waddr, raddr;
    // which page of memory to read/write from
    reg wpage;
    wire rpage;


    // ensure that the read and write pages are opposite
    assign rpage = ~wpage;

    // assign outputs
    assign rdata0 = reg_rdata0;
    assign rdata1 = reg_rdata1;

    // handle wpage
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            wpage <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen) begin
                // we're at the last write address and are writing
                wpage <= ~wpage;
            end
        end
    end

    // handle incrementing waddr
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset raddr
            waddr <= 0;
        end
        else begin
            if (wen) begin
                // should wrap once it's full?
                waddr <= waddr + 2;
            end
        end
    end

    // handle writing to the ram
    integer i;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the buffers
            for (i = 0; i < 2**ADDR_WIDTH ; i=i+1) begin
                ram_buf[wpage][i] <= 0;
                ram_buf[rpage][i] <= 0;
            end 
        end
        else begin
            if (wen) begin
                // write to the buffer if the master enables writes
                ram_buf[wpage][waddr + 0] <= wdata0;
                ram_buf[wpage][waddr + 1] <= wdata1;
            end
        end
    end

    // handle incrementing raddr
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset raddr
            raddr <= 0;
        end
        else begin
            if (rsync) begin
                // should wrap once full, write once we're ready to write
                raddr <= raddr + 2;
            end
        end
    end

    // handle rsync
    // rsync should go high once we're done
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            rsync <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen && ~rsync) begin
                // if rsync is low and we finished writing a block, set high
                rsync <= 1;
            end
            else if (raddr == 2**ADDR_WIDTH-2 && rsync && waddr < 2**ADDR_WIDTH-2) begin
                // if we're about to finish reading, but not done writing, clear
                rsync <= 0;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync <= rsync;
            end
        end
    end

    // handle reading from the ram
    always @(posedge i_clk) begin
        reg_rdata0 <= ram_buf[rpage][raddr + 0];
        reg_rdata1 <= ram_buf[rpage][raddr + 1];
    end


endmodule
