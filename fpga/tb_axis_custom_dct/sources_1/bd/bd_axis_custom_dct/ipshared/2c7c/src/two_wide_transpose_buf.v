`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: two_wide_transpose_buf
// Description:
//  2-port transpose buffer
//  The writer can control the block. Once a block is written it's assumed that
//  the reader will accept one set of read data per clock cycle
//
// Last Modified: 2021-03-02
//
//////////////////////////////////////////////////////////////////////////////////


module two_wide_transpose_buf #(
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
//    localparam DATA_NBITS = $clog2(DATA_WIDTH);
    localparam DATA_NBITS = 3; 
    localparam ADDR_WIDTH_HALF = ADDR_WIDTH>>1;

    // create internal signals
    // transpose buffer
    reg [DATA_WIDTH-1 : 0] ram_buf [0: 1][0 : 2**ADDR_WIDTH_HALF-1][0 : 2**ADDR_WIDTH_HALF-1];
    // output buffers
    reg [DATA_WIDTH-1 : 0] reg_rdata0, reg_rdata1;
    // internal waddr and raddr
    reg [ADDR_WIDTH-1 : 0] waddr, raddr;
    // which page of memory to read/write from
    reg wpage;
    wire rpage;
    reg rsync_ready, w_done;


    // ensure that the read and write pages are opposite
    assign rpage = ~wpage;

    // assign outputs
    assign rdata0 = reg_rdata0;
    assign rdata1 = reg_rdata1;

    // handle wpage
    initial wpage = 0;
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

    initial waddr = 0;
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
    initial begin
        for (i=0; i<2**ADDR_WIDTH-1 ; i=i+1) begin
            ram_buf[wpage][(i%8)][i>>DATA_NBITS] <= 0;
        end
    end
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset the buffers
            for (i = 0; i < 2**ADDR_WIDTH-1 ; i=i+2) begin
                ram_buf[wpage][(i%8)+0][i>>DATA_NBITS] <= 0;
                ram_buf[wpage][(i%8)+1][i>>DATA_NBITS] <= 0;
            end 
        end
        else begin
            if (wen) begin
                // write to the buffer if the master enables writes
//                ram_buf[wpage][row][col]
//                 normally we would increment columns, and write a row at a time
//                  for the double buffer we want to increment rows, and write a column at a time
                ram_buf[wpage][(waddr%8)+0][waddr>>DATA_NBITS] <= wdata0;
                ram_buf[wpage][(waddr%8)+1][waddr>>DATA_NBITS] <= wdata1;
            end
        end
    end

    
    // handle incrementing raddr
    initial raddr = 0;
    always @(posedge i_clk) begin
        if (~i_resetn) begin
            // reset raddr
            raddr <= 0;
        end
        else begin
            if (rsync_ready) begin
                // should wrap once full, write once we're ready to write
                raddr <= raddr + 2;
            end
        end
    end

    // handle rsync
    // rsync should go high once we're done
    initial rsync = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            rsync <= 0;
        end
        else begin
            if (rsync_ready) begin
                // if rsync is low and we finished writing a block, set high
                rsync <= 1;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync <= 0;
            end
        end
    end

    // handle w_done
    // this should just track every time we finish a write, for bookeeping
    initial w_done = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            w_done <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen)
                w_done <= 1;
            else if (waddr == 0)
                w_done <= 0;
        end
    end
    

    // handle rsync
    // rsync should go high once we're done
    initial rsync_ready = 0;
    always @(posedge i_clk) begin
        if(~i_resetn) begin
            rsync_ready <= 0;
        end
        else begin
            if (waddr == 2**ADDR_WIDTH-2 && wen && !rsync_ready) begin
                // if rsync is low and we finished writing a block, set high
                rsync_ready <= 1;
            end
            else if (raddr == 2**ADDR_WIDTH-2 && rsync_ready && !w_done && !(waddr == 2**ADDR_WIDTH-2)) begin
                // we're about to finish reading, but have not completed a write this cycle
                rsync_ready <= 0;
            end
            else begin
                // if we're about to finish writing and rsync is high, stay high
                rsync_ready <= rsync_ready;
            end
        end
    end

    // handle reading from the ram
    initial reg_rdata0 = 0;
    initial reg_rdata1 = 0;
    always @(posedge i_clk) begin
        reg_rdata0 <= ram_buf[rpage][raddr>>DATA_NBITS][(raddr%8)+0];
        reg_rdata1 <= ram_buf[rpage][raddr>>DATA_NBITS][(raddr%8)+1];
    end


endmodule