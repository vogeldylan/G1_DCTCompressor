
`timescale 1 ns / 1 ps

	module sd_control_ram_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        // For Controller-SPI
        output wire cs,
        output wire mosi,
        input wire miso,
        output wire spi_sclk, //For spi connection
        input wire sd_clock, //25Mhz
        // SDIO lines
        output wire sd_reset, dat1, dat2,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	// For external connections
	assign sd_reset = 0;
	assign dat1 = 0;
	assign dat2 = 0;
	// SD card controller
    wire ready, ready_for_next_byte, byte_available;
    wire [4:0] sd_status;
    wire[7:0] dout;
    wire[7:0] din;

    wire[C_S00_AXI_DATA_WIDTH-1:0] slv_reg0, slv_reg2;
    // RAM communication
    wire[8:0] wr_addr_off, rd_addr_off;
    
    // Instantiation of Axi Bus Interface S00_AXI
	sd_control_ram_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) sd_control_ram_v1_0_S00_AXI_inst (
	    .rd_addr_off(rd_addr_off),
        .wr_addr_off(wr_addr_off),
        .din(din),
	    .ready(ready),
        .ready_for_next_byte(ready_for_next_byte),
        .byte_available(byte_available),
        .status(sd_status),
        .dout(dout),
        .sd_clock(sd_clock),
        .slv_reg0(slv_reg0),
        .slv_reg2(slv_reg2),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
    // SD card controller
    sd_controller1 SD(
        .rd_addr_off(rd_addr_off),
        .wr_addr_off(wr_addr_off),
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .sclk(spi_sclk),
        .rd(slv_reg0[2:2]),
        .dout(dout),
        .byte_available(byte_available),
        .wr(slv_reg0[1:1]),
        .din(din),
        .reset(slv_reg0[0:0]),
        .ready_for_next_byte(ready_for_next_byte),
        .ready(ready),
        .address(slv_reg2[31:0]),
        .clk(sd_clock),
        .status(sd_status)
      );
	// User logic ends


	endmodule
