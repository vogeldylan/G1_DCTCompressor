`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: dct_axi_wrapper
// Description:
//  AXI wrapper for the DCT block
//
// Last Modified: 2021-03-02
//
//////////////////////////////////////////////////////////////////////////////////
module custom_dct_axi #(
    parameter DATA_WIDTH = 8,
    parameter BUF_ADDR_WIDTH = 6,
    parameter COEFF_WIDTH = 12,
    parameter FIRST_STAGE_WIDTH = 12,
    parameter SECOND_STAGE_WIDTH = 8
)
(
    input aclk,
    input aresetn,
  
//   output intn,  // active-low interrupt to tell the master we're done

    // AXI-Lite slave interface
    // note, we take two inputs at a time, so if the data width is 8 then we have 16-bit wide busses
    input [31 : 0]                  S_AXI_AWADDR, // technically this is incorrect
    input                           S_AXI_AWVALID,
    output                          S_AXI_AWREADY,

    input [31 : 0]                  S_AXI_WDATA,
    input [3 : 0]                   S_AXI_WSTRB, // # of bytes
    input                           S_AXI_WVALID,
    output                          S_AXI_WREADY,

    output [1:0]                    S_AXI_BRESP,
    output                          S_AXI_BVALID,
    input                           S_AXI_BREADY,

    input [31 : 0]                  S_AXI_ARADDR, // if you set the lowest 3 bits to 000 then the upper BUF_ADDR_WIDTH-1 bits are the memory
    input                           S_AXI_ARVALID,
    output                          S_AXI_ARREADY,

    output [31 : 0]  S_AXI_RDATA,
    output [1:0]                    S_AXI_RRESP,
    output                          S_AXI_RVALID,
    input                           S_AXI_RREADY

);
    
	localparam integer ADDR_LSB = 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;


    // AXI4LITE slave signals
    reg [31 : 0]    s_axi_awaddr;
	reg  	        s_axi_awready;
	reg  	        s_axi_wready;
	reg [1 : 0] 	s_axi_bresp;
	reg  	        s_axi_bvalid;
	reg [31: 0]     s_axi_araddr;
	reg  	        s_axi_arready;
	reg [31 : 0] 	s_axi_rdata;
	reg [1 : 0] 	s_axi_rresp;
	reg  	        s_axi_rvalid;
	
	
	wire	      slv_reg_rden;
	wire	      slv_reg_wren;
	reg [31 : 0]  reg_data_out;
	reg	          s_aw_en; 
	// integer	      byte_index;
	// reg           m_w_en;

	// I/O Slave Connection assignments
	assign S_AXI_AWREADY=  s_axi_awready;
	assign S_AXI_WREADY	=  s_axi_wready;
	assign S_AXI_BRESP	=  s_axi_bresp;
	assign S_AXI_BVALID	=  s_axi_bvalid;
	assign S_AXI_ARREADY=  s_axi_arready;
	assign S_AXI_RDATA	=  s_axi_rdata;
	assign S_AXI_RRESP	=  s_axi_rresp;
	assign S_AXI_RVALID	=  s_axi_rvalid;
	

    reg [DATA_WIDTH-1 : 0] inbuf_wdata0, inbuf_wdata1;
    reg inbuf_wen; // enable writing to the input buffer
    wire [DATA_WIDTH-1 : 0] inbuf_rdata0, inbuf_rdata1, outbuf_wdata0, outbuf_wdata1, outbuf_rdata0, outbuf_rdata1;
    wire inbuf_rsync, outbut_rsync, outbuf_wen, outbuf_rsync;

    // output RAM signals
    reg out_ram_vld;
    reg [BUF_ADDR_WIDTH-1 : 0] s_axi_out_ram_addr; // address that the AXI master is currently reading from
    reg [BUF_ADDR_WIDTH-1 : 0] out_ram_addr;
    reg [SECOND_STAGE_WIDTH-1 : 0] out_ram [0 : 2**BUF_ADDR_WIDTH-1];
	
	// instantantiate the input buffer
	two_wide_double_buf #(DATA_WIDTH, BUF_ADDR_WIDTH)
        input_buf(
            .i_clk(aclk),
            .i_resetn(aresetn),
            .wdata0(inbuf_wdata0),
            .wdata1(inbuf_wdata1),
            .wen(inbuf_wen),
            .rdata0(inbuf_rdata0),
            .rdata1(inbuf_rdata1),
            .rsync(inbuf_rsync)
            );

    // instantantiate the dct main block
    dct_main #(DATA_WIDTH, COEFF_WIDTH, FIRST_STAGE_WIDTH, SECOND_STAGE_WIDTH)
        dct_main(
            .i_clk(aclk),
            .i_resetn(aresetn),
            .wdata0(inbuf_rdata0),
            .wdata1(inbuf_rdata1),
            .wen(inbuf_rsync),
            .rdata0(outbuf_wdata0),
            .rdata1(outbuf_wdata1),
            .rsync(outbuf_wen)
            );

    // instantantiate the output buffer
    two_wide_double_buf #(SECOND_STAGE_WIDTH, BUF_ADDR_WIDTH)
        output_buf(
            .i_clk(aclk),
            .i_resetn(aresetn),
            .wdata0(outbuf_wdata0),
            .wdata1(outbuf_wdata1),
            .wen(outbuf_wen),
            .rdata0(outbuf_rdata0),
            .rdata1(outbuf_rdata1),
            .rsync(outbuf_rsync)
            );
	

    // handle out_ram_vld signal
    always @(posedge aclk) begin
        if (~aresetn) begin
            out_ram_vld <= 0;
        end
        else begin
            if (outbuf_rsync) begin
                // all data from now on is valid
                // I recommend you start reading at address 0, however
                out_ram_vld <= 1;
            end    
        end
    end

    // handle writing to the output RAM
    integer a;
    always @(posedge aclk) begin
        if (~aresetn) begin
            // reset the address
            out_ram_addr <= 0;
            // reset the buffer
            for (a = 0; a < 2**BUF_ADDR_WIDTH ; a=a+1 ) begin
                out_ram[a] <= 0;
            end 
        end
        else begin
            if (outbuf_rsync) begin
                // write to the output RAM
                out_ram[out_ram_addr + 0] <= outbuf_rdata0;
                out_ram[out_ram_addr + 1] <= outbuf_rdata1;
                // increment the address
                out_ram_addr = out_ram_addr + 2;
            end
        end
    end


    // Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = s_axi_wready && S_AXI_WVALID && s_axi_awready && S_AXI_AWVALID;

	always @( posedge aclk ) begin
	    if ( aresetn == 1'b0 ) begin
            // reset everything
            inbuf_wdata0 <= inbuf_wdata0;
            inbuf_wdata1 <= inbuf_wdata1;
        end 
	    else begin
	        if (slv_reg_wren) begin
                // if the necessary slave write signals are valid
                case ( s_axi_awaddr[3:2] ) // TODO: make this not hardcoded
                    2'h0: begin
                        // write data to the DCT input buffer
                        inbuf_wdata0 <= S_AXI_WDATA[7 : 0];
                        inbuf_wdata1 <= S_AXI_WDATA[15: 8];
                    end
                    default : begin
                        inbuf_wdata0 <= inbuf_wdata0;
                        inbuf_wdata1 <= inbuf_wdata1;
                    end
                endcase
	        end
	    end
	end
	
	
	// specific block to handle inbuf_wen
	always @( posedge aclk ) begin
	    if ( aresetn == 1'b0 ) begin
                // disable writing
                inbuf_wen <= 1'b0;
            end
	    else begin
            if ( slv_reg_wren && s_axi_awaddr[3:2] == 2'h0 && aresetn) begin
                // writing valid data, set high
                inbuf_wen <= 1'b1;
                end
            else begin
                // otherwise disable
                inbuf_wen <= 1'b0;
            end
	    end
    end 


    // Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = s_axi_arready & S_AXI_ARVALID & ~s_axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( s_axi_araddr[3:2] )
	        2'h0   : begin
                // we have selected to read the output buffer
                reg_data_out[7 : 0]     <= out_ram[s_axi_out_ram_addr + 0];
                reg_data_out[15 : 8]    <= out_ram[s_axi_out_ram_addr + 1];
                reg_data_out[23 : 16]   <= out_ram[s_axi_out_ram_addr + 2];
                reg_data_out[31 : 24]   <= out_ram[s_axi_out_ram_addr + 3];
            end
            2'h1   : begin
                // use this to check if the output ram is now a valid stream
                reg_data_out[0] <= out_ram_vld;
            end
	        default : begin
	           reg_data_out <= 0;
	        end
	      endcase
	end
	
	always @(posedge aclk) begin
	   if (~aresetn) begin
	       // reset the read address
	       s_axi_out_ram_addr <= 0;
	   end
	   else begin
	       if (s_axi_araddr[3:2]==2'h0 && slv_reg_rden) begin
	           // increment by four because we read four values each time
	           s_axi_out_ram_addr = s_axi_out_ram_addr + 4; 
	       end
	   end
	end

	// Output register or memory read data
	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          s_axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end


	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_awready <= 1'b0;
	      s_aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~s_axi_awready && S_AXI_AWVALID && S_AXI_WVALID && s_aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          s_axi_awready <= 1'b1;
	          s_aw_en <= 1'b0;
	        end
          else if (S_AXI_BREADY && s_axi_bvalid)
	            begin
	              s_aw_en <= 1'b1;
	              s_axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          s_axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~s_axi_awready && S_AXI_AWVALID && S_AXI_WVALID && s_aw_en)
	        begin
	          // Write Address latching 
	          s_axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~s_axi_wready && S_AXI_WVALID && S_AXI_AWVALID && s_aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          s_axi_wready <= 1'b1;
	        end
	      else
	        begin
	          s_axi_wready <= 1'b0;
	        end
	    end 
	end       


	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_bvalid  <= 0;
	      s_axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (s_axi_awready && S_AXI_AWVALID && ~s_axi_bvalid && s_axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          s_axi_bvalid <= 1'b1;
	          s_axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && s_axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              s_axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_arready <= 1'b0;
	      s_axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~s_axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          s_axi_arready <= 1'b1;
	          // Read address latching
	          s_axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          s_axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      s_axi_rvalid <= 0;
	      s_axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (s_axi_arready && S_AXI_ARVALID && ~s_axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          s_axi_rvalid <= 1'b1;
	          s_axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (s_axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          s_axi_rvalid <= 1'b0;
	        end                
	    end
	end    


	
	
	// // awvalid logic
	// // assert awvalid immediately after getting init_write
	// // reset once the slave acknowledges both signals
	// always @(posedge aclk)
	// begin
	//    	if ( aresetn == 1'b0 ) // reset
	//        	begin
	//            	m_axi_awvalid <= 1'b0;
	//        	end
	// 	else 
	// 		begin
	// 			if ( init_write & ~m_axi_awvalid )
	// 				// assert if init write and both are low
	// 				begin
	// 					m_axi_awvalid <= 1'b1;
	// 				end
	// 			else if ( M_AXI_AWREADY & m_axi_awvalid )
	// 				// de-assert if the slave acknowledges on the next rising edge
	// 				begin
	// 					m_axi_awvalid <= 1'b0;
	// 				end
	// 		end
	// end
	
	// // wvalid logic
	// // assert wvalid and wvalid immediately after getting init_write
	// // reset once the slave acknowledges both signals
	// always @(posedge aclk)
	// begin
	//    	if ( aresetn == 1'b0 ) // reset
	//        	begin
	// 		   	m_axi_wvalid <= 1'b0;
	//        	end
	// 	else 
	// 		begin
	// 			if ( init_write & ~m_axi_wvalid)
	// 				// assert if init write wvalid is low
	// 				begin
	// 					m_axi_wvalid <= 1'b1;
	// 				end
	// 			else if ( M_AXI_WREADY & m_axi_wvalid)
	// 				// de-assert if the slave acknowledges on the next rising edge
	// 				begin
	// 					m_axi_wvalid <= 1'b0;
	// 				end
	// 		end
	// end


    // // m_axi_bready logic
    // // only assert bready once the slave asserts bvalid, then read the response on the next cycle
	// always @(posedge aclk)
	// begin
	//    	if ( aresetn == 1'b0 ) // reset
	//        	begin
	//            	m_axi_bready <= 1'b0;
	//        	end
	// 	else 
	// 		begin
	// 			if ( M_AXI_BVALID & ~m_axi_bready )
	// 				// the slave can only acknowledge when it drives a valid response
	// 				begin
	// 					m_axi_bready <= 1'b1;
	// 				end
	// 			else if ( M_AXI_BVALID & m_axi_bready )
	// 				// de-assert if we both acknowledge
	// 				begin
	// 					if ( M_AXI_BRESP != 2'b0 )
	// 						begin
	// 							$display("ERROR: got slave response: %0h", M_AXI_BRESP);
	// 						end
	// 					m_axi_bready <= 1'b0;
	// 				end
	// 		end
	// end

endmodule