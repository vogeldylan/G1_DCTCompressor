`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Team: HEALTH
// Engineer: Dylan Vogel
// 
// Module Name: tb_axi_custom_dct_mst.sv
// Description:
//  master driver for the custom_dct axi testbench
//  copied from Xilinx's example master driver
//
// Last Modified: 2021-03-09
//
//////////////////////////////////////////////////////////////////////////////////


/***************************************************************************************************
* Description: 
* This file contains examples showing how user can generate simple write and/or read transaction 
* According to VIP's WRITE_READ_MODE. user will see different examples.
* WRITE_ONLY - simple write transaction
* READ_ONLY  - simple read transaction
* READ_WRITE - both simple write and read transaction

*  For Master VIP to work correctly, user environment MUST have to do the following lists of item
*  and follow the same order as shown here.  Item 1 to 5 can be copied into a user testbench and
*  care of the ordering must be taken into account.    
*    1. import two packages.
*         import axi_vip_pkg::*; 
*         import <component_name>_pkg::*;
*    2. delcare <component_name>_mst_t agent
*    3. new agent (passing instance IF correctly)
*    4. start_master
*    5. generate transaction/
* More details about generating transaction please refer tasks below.
*
* In this file,it shows how to generate a write/read transaction in three ways(fully randomization,
* partial randomization and API), it then shows how to get read data back from driver,how
* generate write in data and then read it back.
*  
***************************************************************************************************/

import axi_vip_pkg::*;
import bd_axis_custom_dct_axi_vip_0_0_pkg::*;

module axis_vip_0_mst_stimulus();
  
  /*************************************************************************************************
  * <component_name>_mst_t for master agent
  * <component_name> can be easily found in vivado bd design: click on the instance, 
  * Then click CONFIG under Properties window and Component_Name will be shown
  * More details please refer PG267 section about "Useful Coding Guidelines and Examples"
  * for more details.
  *************************************************************************************************/
  bd_axis_custom_dct_axi_vip_0_0_mst_t                               agent;

  /*************************************************************************************************
  * Declare variables which will be used in API and parital randomization for transaction generation
  * and data read back from driver.
  *************************************************************************************************/
  axi_transaction                                          wr_trans;            // Write transaction
  axi_transaction                                          rd_trans;            // Read transaction
  xil_axi_uint                                             mtestWID;            // Write ID  
  xil_axi_ulong                                            mtestWADDR;          // Write ADDR  
  xil_axi_len_t                                            mtestWBurstLength;   // Write Burst Length   
  xil_axi_size_t                                           mtestWDataSize;      // Write SIZE  
  xil_axi_burst_t                                          mtestWBurstType;     // Write Burst Type  
  xil_axi_uint                                             mtestRID;            // Read ID  
  xil_axi_ulong                                            mtestRADDR;          // Read ADDR  
  xil_axi_len_t                                            mtestRBurstLength;   // Read Burst Length   
  xil_axi_size_t                                           mtestRDataSize;      // Read SIZE  
  xil_axi_burst_t                                          mtestRBurstType;     // Read Burst Type  

  xil_axi_data_beat [255:0]                                mtestWUSER;         // Write user  
  xil_axi_data_beat                                        mtestAWUSER;        // Write Awuser 
  xil_axi_data_beat                                        mtestARUSER;        // Read Aruser 
  /************************************************************************************************
  * A burst can not cross 4KB address boundry for AXI4
  * Maximum data bits = 4*1024*8 =32768
  * Write Data Value for WRITE_BURST transaction
  * Read Data Value for READ_BURST transaction
  ************************************************************************************************/
  bit [32767:0]                                            mtestWData;         // Write Data 
  bit[8*4096-1:0]                                          Rdatablock;        // Read data block
  xil_axi_data_beat                                        Rdatabeat[];       // Read data beats
  bit[8*4096-1:0]                                          Wdatablock;        // Write data block
  xil_axi_data_beat                                        Wdatabeat[];       // Write data beats
 
  // localparam DCT_BASE_ADDR      = 'h00000000;
  // localparam DCT_DATA_OFFSET    = 'h0;
  // localparam DCT_VLD_OFFSET     = 'h4;
  
  localparam BRAM_BASE_ADDR     = 'hC0000000; // memory base address
  localparam AXI_DMA_BASE_ADDR  = 'h41E00000; // axi DMA registers base addr

  // memory map to stream 
  localparam AXI_DMA_MM2S_DMACR     = 'h00;
  localparam AXI_DMA_MM2S_DMASR     = 'h04;
  localparam AXI_DMA_MM2S_SA        = 'h18;
  localparam AXI_DMA_MM2S_SA_MSB    = 'h1C;
  localparam AXI_DMA_MM2S_LENGTH    = 'h28;
  
  // stream to memory map
  localparam AXI_DMA_S2MM_DMACR     = 'h30;
  localparam AXI_DMA_S2MM_DMASR     = 'h34;
  localparam AXI_DMA_S2MM_DA        = 'h48;
  localparam AXI_DMA_S2MM_DA_MSB    = 'h4C;
  localparam AXI_DMA_S2MM_LENGTH    = 'h58;
  
  localparam AXI_DMA_CR_START       = 1 << 0;
  localparam AXI_DMA_CR_SOFT_RST    = 1 << 2;


  localparam AXI_DMA_SR_HALTED      = 1 << 0;
  localparam AXI_DMA_SR_IDLE        = 1 << 1;
  localparam AXI_DMA_SR_RD_ERR      = 1 << 5;
  localparam AXI_DMA_SR_DEC_ERR     = 1 << 6;

  // stream to memory map start dest address
  // set the DMA controller to write in the upper 4096 addresses 
  localparam S2MM_BRAM_BASE_ADDR    = BRAM_BASE_ADDR + 'h1000;

  xil_axi_data_beat rd_data_beat[]; // each array element is 32 bits wide
  int unsigned i, out_vld, j, waiting;
  
//  int unsigned read_status;
  int unsigned read_data;

  reg [7:0] rd0, rd1, rd2, rd3;

  initial begin
    /***********************************************************************************************
    * Before agent is newed, user has to run simulation with an empty testbench to find the hierarchy
    * path of the AXI VIP's instance.Message like
    * "Xilinx AXI VIP Found at Path: my_ip_exdes_tb.DUT.ex_design.axi_vip_mst.inst" will be printed 
    * out. Pass this path to the new function. 
    ***********************************************************************************************/
    agent = new("master vip agent", DUT.bd_axis_custom_dct_i.axi_vip_0.inst.IF);
    agent.start_master();               // agent start to run

//    $monitor("INFO: read data: %0h", rd_data_beat[0]);

    // begin writing data to memory
    for (i = 0; i < 128 ; i=i+4) begin
      // write a bunch of data to the DCT block
      // write {i+1, i} as 16 bits of data
      write_register(BRAM_BASE_ADDR + i, (i+3)<<24 | (i+2)<<16 | (i+1)<<8 | i);
    end
       
    // wait for BRAM to finish
    agent.wait_drivers_idle();

    // see pg 70 of the guide for programming sequence 
    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_MM2S_DMACR, AXI_DMA_CR_START);
    
    waiting = 0;
    while (!waiting) begin
      $display("waiting for MM2S to startup ....");
      read_register(AXI_DMA_BASE_ADDR + AXI_DMA_MM2S_DMASR, rd_data_beat);
      if (!(rd_data_beat[0] & AXI_DMA_SR_HALTED)) begin
        waiting = 1;
      end
    end
    $display("MM2S has started up");

    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_MM2S_SA, BRAM_BASE_ADDR); // set to read from BRAM base addr
    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_MM2S_LENGTH, 128); // read 64 bytes and transfer to stream
    
    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_S2MM_DMACR, AXI_DMA_CR_START);

    waiting = 0;
    while (!waiting) begin
      $display("waiting for S2MM to startup ....");
      read_register(AXI_DMA_BASE_ADDR + AXI_DMA_S2MM_DMASR, rd_data_beat);
      if (!(rd_data_beat[0] & AXI_DMA_SR_HALTED)) begin
        waiting = 1;
      end
    end
    $display("S2MM has started up");

    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_S2MM_DA, S2MM_BRAM_BASE_ADDR);
    write_register(AXI_DMA_BASE_ADDR + AXI_DMA_S2MM_LENGTH, 128); // SET THIS ONE MORE THAN YOU NEED FOR IT TO NOT COMPLAIN

    waiting = 0;
    while (!waiting) begin
      $display("waiting for MM2S to complete data transfer ...");
      read_register(AXI_DMA_BASE_ADDR + AXI_DMA_MM2S_DMASR, rd_data_beat);
      // $display("%0b", rd_data_beat[0]);
      if (rd_data_beat[0] & AXI_DMA_SR_IDLE) begin
        waiting = 1;
      end
    end

    $display("MM2S has completed data transfer to DCT block");

    waiting = 0;
    while (!waiting) begin
      $display("waiting for S2MM to complete data transfer ...");
      read_register(AXI_DMA_BASE_ADDR + AXI_DMA_S2MM_DMASR, rd_data_beat);
      $display("%0b", rd_data_beat[0]);
      if (rd_data_beat[0] & AXI_DMA_SR_IDLE || rd_data_beat[0] & AXI_DMA_SR_HALTED) begin // CHECK HALTED IN CASE IT'S DUMB
        waiting = 1;
      end
    end

    $display("S2MM has completed transferring data to memory");


    $display("Coefficient Data Read from BRAM:\n");

    for (j = 0; j < 64; j=j+4) begin
      read_register(S2MM_BRAM_BASE_ADDR + j, rd_data_beat);
      {rd3, rd2, rd1, rd0} = rd_data_beat[0];
      $display("%0h\t%0h\t%0h\t%0h", rd0, rd1, rd2, rd3);
    end

  end // initial



  // write to a register
  task write_register(input xil_axi_ulong addr, input reg [31:0] data );
    // send the write transaction
    single_write_transaction_api("single write with api",
                                  .addr(addr),
                                  .size(xil_axi_size_t'(2)),
                                  .data(data)
                                  );
  endtask : write_register

  // read from a register
  task read_register(input xil_axi_ulong addr, output xil_axi_data_beat rd_data_beat[]);
    axi_transaction rd_trans;
    // send the read transaction
    single_read_transaction_api("single read with api",
                                .addr(addr),
                                .size(xil_axi_size_t'(2)),
                                .rd_trans(rd_trans)
                                );
    // get the data back
    get_rd_data_beat_back(rd_trans, rd_data_beat);
  endtask : read_register

  /************************************************************************************************
  * Task send_wait_rd is a task which set_driver_return_item_policy of the read transaction, 
  * send the transaction to the driver and wait till it is done
  *************************************************************************************************/
  task send_wait_rd(inout axi_transaction rd_trans);
    rd_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    agent.rd_driver.send(rd_trans);
    agent.rd_driver.wait_rsp(rd_trans);
  endtask

  /************************************************************************************************
  * Task get_rd_data_beat_back is to get read data back from read driver with
  *  data beat format.
  *************************************************************************************************/
  task get_rd_data_beat_back(inout axi_transaction rd_trans, 
                                 output xil_axi_data_beat Rdatabeat[]
                            );  
    send_wait_rd(rd_trans);
    Rdatabeat = new[rd_trans.get_len()+1];
    for( xil_axi_uint beat=0; beat<rd_trans.get_len()+1; beat++) begin
      Rdatabeat[beat] = rd_trans.get_data_beat(beat);
   //   $display("Read data from Driver: beat index %d, Data beat %h ", beat, Rdatabeat[beat]);
    end  
  endtask

  /************************************************************************************************
  * Task get_rd_data_block_back is to get read data back from read driver with
  * data block format.
  *************************************************************************************************/
  task get_rd_data_block_back(inout axi_transaction rd_trans, 
                                 output bit[8*4096-1:0] Rdatablock
                            );  
    send_wait_rd(rd_trans);
    Rdatablock = rd_trans.get_data_block();
    // $display("Read data from Driver: Block Data %h ", Rdatablock);
  endtask

  /************************************************************************************************
  * Task send_wait_wr is a task which set_driver_return_item_policy of the write transaction, 
  * send the transaction to the driver and wait till it is done
  *************************************************************************************************/
  task send_wait_wr(inout axi_transaction wr_trans);
    wr_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    agent.wr_driver.send(wr_trans);
    agent.wr_driver.wait_rsp(wr_trans);
  endtask

  /************************************************************************************************
  * Task get_wr_data_beat_back is to get read data back from write driver with
  * data beat format.
  *************************************************************************************************/
  task get_wr_data_beat_back(inout axi_transaction wr_trans, 
                                 output xil_axi_data_beat Wdatabeat[]
                            );  
    send_wait_wr(wr_trans);
    Wdatabeat = new[wr_trans.get_len()+1];
    for( xil_axi_uint beat=0; beat<wr_trans.get_len()+1; beat++) begin
      Wdatabeat[beat] = wr_trans.get_data_beat(beat);
   //   $display("Write data from Driver: beat index %d, Data beat %h ", beat, Wdatabeat[beat]);
    end  
  endtask

  /************************************************************************************************
  * Task get_wr_data_block_back is to get write data back from write driver with
  * data block format.
  *************************************************************************************************/
  task get_wr_data_block_back(inout axi_transaction wr_trans, 
                                 output bit[8*4096-1:0] Wdatablock
                            );  
    send_wait_wr(wr_trans);
    Wdatablock = wr_trans.get_data_block();
    // $display("Write data from Driver: Block Data %h ", Wdatablock);
  endtask


  /************************************************************************************************
  *  task single_write_transaction_api is to create a single write transaction, fill in transaction 
  *  by using APIs and send it to write driver.
  *   1. declare write transction
  *   2. Create the write transaction
  *   3. set addr, burst,ID,length,size by calling set_write_cmd(addr, burst,ID,length,size), 
  *   4. set prot.lock, cache,region and qos
  *   5. set beats
  *   6. set AWUSER if AWUSER_WIDH is bigger than 0
  *   7. set WUSER if WUSR_WIDTH is bigger than 0
  *************************************************************************************************/

  task automatic single_write_transaction_api ( 
                                input string                     name ="single_write",
                                input xil_axi_uint               id =0, 
                                input xil_axi_ulong              addr =0,
                                input xil_axi_len_t              len =0, 
                                input xil_axi_size_t             size =xil_axi_size_t'(xil_clog2((32)/8)),
                                input xil_axi_burst_t            burst =XIL_AXI_BURST_TYPE_INCR,
                                input xil_axi_lock_t             lock = XIL_AXI_ALOCK_NOLOCK,
                                input xil_axi_cache_t            cache =3,
                                input xil_axi_prot_t             prot =0,
                                input xil_axi_region_t           region =0,
                                input xil_axi_qos_t              qos =0,
                                input xil_axi_data_beat [255:0]  wuser =0, 
                                input xil_axi_data_beat          awuser =0,
                                input bit [32767:0]              data =0
                                                );
    axi_transaction                               wr_trans;
    wr_trans = agent.wr_driver.create_transaction(name);
    wr_trans.set_write_cmd(addr,burst,id,len,size);
    wr_trans.set_prot(prot);
    wr_trans.set_lock(lock);
    wr_trans.set_cache(cache);
    wr_trans.set_region(region);
    wr_trans.set_qos(qos);
    wr_trans.set_data_block(data);
    agent.wr_driver.send(wr_trans);   
  endtask  : single_write_transaction_api

  /************************************************************************************************
  *  task single_read_transaction_api is to create a single read transaction, fill in command with user
  *  inputs and send it to read driver.
  *   1. declare read transction
  *   2. Create the read transaction
  *   3. set addr, burst,ID,length,size by calling set_read_cmd(addr, burst,ID,length,size), 
  *   4. set prot.lock, cache,region and qos
  *   5. set ARUSER if ARUSER_WIDH is bigger than 0
  *************************************************************************************************/
  task automatic single_read_transaction_api ( 
                                    input string                     name ="single_read",
                                    input xil_axi_uint               id =0, 
                                    input xil_axi_ulong              addr =0,
                                    input xil_axi_len_t              len =0, 
                                    input xil_axi_size_t             size =xil_axi_size_t'(xil_clog2((32)/8)),
                                    input xil_axi_burst_t            burst =XIL_AXI_BURST_TYPE_INCR,
                                    input xil_axi_lock_t             lock =XIL_AXI_ALOCK_NOLOCK ,
                                    input xil_axi_cache_t            cache =3,
                                    input xil_axi_prot_t             prot =0,
                                    input xil_axi_region_t           region =0,
                                    input xil_axi_qos_t              qos =0,
                                    input xil_axi_data_beat          aruser =0,
                                    output axi_transaction           rd_trans
                                                );
//    axi_transaction                               rd_trans;
    rd_trans = agent.rd_driver.create_transaction(name);
    rd_trans.set_read_cmd(addr,burst,id,len,size);
    rd_trans.set_prot(prot);
    rd_trans.set_lock(lock);
    rd_trans.set_cache(cache);
    rd_trans.set_region(region);
    rd_trans.set_qos(qos);
    agent.rd_driver.send(rd_trans);   
  endtask  : single_read_transaction_api
 

  
  /*************************************************************************************************
  * This task is to queue up multiple transactions with the same id, length,size, burst type
  * and incrementd addr with different data. then it send out all these transactions
  * 1. Declare a handle for read transaction
  * 2. set delay range if user set there transction is of no delay
  * 3. constraint randomize the transaction
  * 4. increment the addr
  * 5. repeat 1-4 to generate num_xfer transaction
  * 6. send out the transaction
  *************************************************************************************************/
  
  task automatic multiple_read_transaction(
                              input xil_axi_uint    num_xfer =1,
                              input xil_axi_ulong   start_addr =0,
                              input xil_axi_uint    id =0,
                              input xil_axi_len_t   len =0,
                              input xil_axi_size_t  size =xil_axi_size_t'(xil_clog2((32)/8)),
                              input xil_axi_burst_t burst = XIL_AXI_BURST_TYPE_INCR,
                              input bit             no_xfer_delays =0  
                                        );
    axi_transaction                                          rd_tran[];
    xil_axi_ulong                                            addr;

    rd_tran =new[num_xfer];
    addr = start_addr;

    // queue up transactions
    for (int i =0; i <num_xfer; i++) begin
      rd_tran[i] = agent.rd_driver.create_transaction($sformatf("read_multiple_transaction id =%0d",i));
      if(no_xfer_delays ==1) begin
        rd_tran[i].set_data_insertion_delay_range(0,0);
        rd_tran[i].set_addr_delay_range(0,0);
        rd_tran[i].set_beat_delay_range(0,0);
      end
      // set the read command
      rd_tran[i].set_read_cmd(addr, burst, id, len, size);
      // TODO: replace the inline_... call with actually setting this transaction  
      // inline_randomize_transaction(.trans(rd_tran[i]), 
      //                              .id_val(id), 
      //                              .addr_val(addr),
      //                              .len_val(len),
      //                              .size_val(size), 
      //                              .burst_val(burst));
      addr += rd_tran[i].get_num_bytes_in_transaction();
    end
    //send out transaction
    for (int i =0; i <num_xfer; i++) begin
       agent.rd_driver.send(rd_tran[i]);
    end
  endtask :multiple_read_transaction

  /*************************************************************************************************  * This task is to queue up multiple transactions with the same id, length,size, burst type
  * and incrementd addr with different data. then it send out all these transactions 
  * 1. Declare a handle for write transaction
  * 2. set delay range if user set there transction is of no delay
  * 3. constraint randomize the transaction
  * 4. increment the addr
  * 5. repeat 1-4 to generate num_xfer transaction
  * 6. send out the transaction
  *************************************************************************************************/
  
  task automatic multiple_write_transaction(
                              input xil_axi_uint    num_xfer =1,
                              input xil_axi_ulong   start_addr =0,
                              input xil_axi_uint    id =0,
                              input xil_axi_len_t   len =0,
                              input xil_axi_size_t  size =xil_axi_size_t'(xil_clog2((32)/8)),
                              input xil_axi_burst_t burst = XIL_AXI_BURST_TYPE_INCR,
                              input bit             no_xfer_delays =0  
                                        );
    axi_transaction                                          wr_tran[];
    xil_axi_ulong                                            addr;

    wr_tran =new[num_xfer];
    addr = start_addr;

    // queue up transactions
    for (int i =0; i <num_xfer; i++) begin
      wr_tran[i] = agent.wr_driver.create_transaction($sformatf("write_multiple_transaction id =%0d",i));
      if(no_xfer_delays ==1) begin
        wr_tran[i].set_data_insertion_delay_range(0,0);
        wr_tran[i].set_addr_delay_range(0,0);
        wr_tran[i].set_beat_delay_range(0,0);
      end
      // TODO: fix this  
      // inline_randomize_transaction(.trans(wr_tran[i]), 
      //                              .id_val(id), 
      //                              .addr_val(addr),
      //                              .len_val(len),
      //                              .size_val(size), 
      //                              .burst_val(burst));
      addr += wr_tran[i].get_num_bytes_in_transaction();
    end
    //send out transaction
    for (int i =0; i <num_xfer; i++) begin
       agent.wr_driver.send(wr_tran[i]);
    end
  endtask :multiple_write_transaction

  /************************************************************************************************
  * multiple_write_in_then_read_back shows user how to write to one address and then read back. 
  * 1. create a write transaction with fixed address, id, length, size, burst type.
  * 2. send the transaction to Master VIP interface and wait till response come back
  * 3. Get write data beat and data block from the driver
  * 4. create a read transaction with the same address, id, length, size and burst type as write transaction
  * 5. send the transaction to Master VIP interface and wait till response come back
  * 6. Get read data beat and data block from the driver
  * 7. user can do a check between write data and read data(if in the enviroment there is memory in the system)
  *    or print out the data information 
  * 8. increment the address and repeat another write in and read back till num_xfer transactions
  *************************************************************************************************/

  task automatic multiple_write_in_then_read_back (
                          input xil_axi_uint    num_xfer =1,
                          input xil_axi_ulong   start_addr =0,
                          input xil_axi_uint    id =0,
                          input xil_axi_len_t   len =0,
                          input xil_axi_size_t  size =xil_axi_size_t'(xil_clog2((32)/8)),
                          input xil_axi_burst_t burst = XIL_AXI_BURST_TYPE_INCR,
                          input bit             no_xfer_delays =0    
                                        );
    axi_transaction                                          wr_trans;
    axi_transaction                                          rd_trans;
    bit[8*4096-1:0]                                          data_block_for_read;
    xil_axi_data_beat                                        DataBeat_for_read[];
    bit[8*4096-1:0]                                          data_block_for_write;
    xil_axi_data_beat                                        DataBeat_for_write[];
    xil_axi_ulong                                            addr;

    addr = start_addr;
    for (int i =0; i <num_xfer; i++) begin
      //write transaction in 
      wr_trans = agent.wr_driver.create_transaction($sformatf("fill in write transaction with inline randomization id =%0d",i));
       if(no_xfer_delays ==1) begin
        wr_trans.set_data_insertion_delay_range(0,0);
        wr_trans.set_addr_delay_range(0,0);
        wr_trans.set_beat_delay_range(0,0);
      end  
      // TODO: fix this
      // inline_randomize_transaction(.trans(wr_trans), 
      //                              .id_val(id), 
      //                              .addr_val(addr),
      //                              .len_val(len),
      //                              .size_val(size), 
      //                              .burst_val(burst));
      get_wr_data_beat_back(wr_trans,DataBeat_for_write);
      data_block_for_write = wr_trans.get_data_block();
      //$display("Write data from Driver: Block Data %h ", data_block_for_write);
      
      // read data back
      rd_trans = agent.rd_driver.create_transaction($sformatf("fill in read transaction with inline randomization id =%0d",i));
      if(no_xfer_delays ==1) begin
        rd_trans.set_data_insertion_delay_range(0,0);
        rd_trans.set_addr_delay_range(0,0);
        rd_trans.set_beat_delay_range(0,0);
      end  
      // inline_randomize_transaction(.trans(rd_trans),
      //                              .id_val(id), 
      //                              .addr_val(addr),
      //                              .len_val(len),
      //                              .size_val(size), 
      //                              .burst_val(burst));
      get_rd_data_beat_back(rd_trans,DataBeat_for_read);
      data_block_for_read = rd_trans.get_data_block();
      //  $display("Read data from Driver: Block Data %h ", data_block_for_read);
      addr += wr_trans.get_num_bytes_in_transaction();
    end
  endtask

  /**********************************************************************************************
  * Note: if multiple agents are called in one testbench,it will be hard to tell which
  * agent is complaining. set_agent_tag can be used to set a name tag for each agent
    agent.set_agent_tag("My Master VIP one");

  * If user wants to know all the details of each transaction, set_verbosity can be used to set
  * up information being printed out or not. Default is no print out 
    * Verbosity level which specifies how much debug information to produce
    *    0       - No information will be printed out.
    *   400      - All information will be printed out
    agent.set_verbosity(0);

  * These two lines should be added anywhere after agent is being newed  
  *************************************************************************************************/


  /*************************************************************************************************
  * There are two ways to get read data. One is to get it through the read driver of master agent. 
  * The other is to get it through the monitor of VIP.(Please refer
  * monitor_rd_data_method_one, monitor_rd_data_method_two in *exdes_generic.sv file.)
  *
  * To get data from read driver, follow the steps listed below. 
  * step 1: Use the read driver in master agent to create a read transaction handle.
  * step 2: Randmoize the read transaction. If the user wants to generate a specific read command, 
            use the APIs in the axi_transaction class to set address, burst length, etc or 
            randomize the transaction with specific values.
  * step 3: Set driver_return_item_policy of the read transaction to be any of the follwing values:
  *         XIL_AXI_PAYLOAD_RETURN or XIL_AXI_CMD_PAYLOAD_RETURN.
  * step 4: Use the read driver to sends read transaction out.
  * step 5: Use the read driver to wait for the response.
  * step 6: Use get_data_beat/get_data_block to inspect data from the response transaction.
  *
  * driver_rd_data_method_one shows how to get a data beat from the read driver.
  * driver_rd_data_method_two shows how to get a data block from the read driver.
  * 
  * Note on API get_data_beat: get_data_beat returns the value of the specified beat. 
  * It always returns 1024 bits. It aligns the signification bytes to the lower 
  * bytes and sets the unused bytes to zeros.
  * This is NOT always the RDATA representation. If the data width is 32-bit and 
  * the transaction is sub-size burst (1B in this example), only the last byte of 
  * get_data_beat is valid. This is very different from the Physical Bus.
  * 
  * get_data_beat            Physical Bus
  * 1024  ...      0          32        0
  * ----------------         -----------
  * |             X|         |        X| 
  * |             X|         |      X  |
  * |             X|         |    X    |
  * |             X|         | X       |
  * ----------------         -----------
  *
  * Note on API get_data_block: get_data_block returns 4K bytes of the payload
  * for the transaction. This is NOT always the RDATA representation.  If the data
  * width is 32-bit and the transaction is sub-size burst (1B in this example),
  * It will align the signification bytes to the lower bytes and set the unused 
  * bytes to zeros.
  *
  *   get_data_block          Physical Bus
  *   32    ...      0         32        0
  * 0 ----------------         -----------
  *   | D   C   B   A|         |        A| 
  *   | 0   0   0   0|         |      B  |
  *   | 0   0   0   0|         |    C    |
  *   | 0   0   0   0|         | D       |
  *   | 0   0   0   0|         -----------
  *   | 0   0   0   0|         
  * 1k----------------         
  *
  *************************************************************************************************/
  
  // task driver_rd_data_method_one();
  //   axi_transaction                         rd_trans;
  //   xil_axi_data_beat                       mtestDataBeat[];
  //   rd_trans = agent.rd_driver.create_transaction("read transaction with randomization");
  //   RD_TRANSACTION_FAIL_1a:assert(rd_trans.randomize());
  //   rd_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  //   agent.rd_driver.send(rd_trans);
  //   agent.rd_driver.wait_rsp(rd_trans);
  //   mtestDataBeat = new[rd_trans.get_len()+1];
  //   for( xil_axi_uint beat=0; beat<rd_trans.get_len()+1; beat++) begin
  //     mtestDataBeat[beat] = rd_trans.get_data_beat(beat);
  //  //   $display("Read data from Driver: beat index %d, Data beat %h ", beat, mtestDataBeat[beat]);
  //   end  
  // endtask 

  
  // task driver_rd_data_method_two();  
  //   axi_transaction                         rd_trans;
  //   bit[8*4096-1:0]                         data_block;
  //   rd_trans = agent.rd_driver.create_transaction("read transaction with randomization");
  //   RD_TRANSACTION_FAIL_1a:assert(rd_trans.randomize());
  //   rd_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  //   agent.rd_driver.send(rd_trans);
  //   agent.rd_driver.wait_rsp(rd_trans);
  //   data_block = rd_trans.get_data_block();
  //  // $display("Read data from Driver: Block Data %h ", data_block);
  // endtask 

  // old xilinx code 
  


    // // Parallel write/read transaction generation 
    // fork                               // Fork process of write/read transaction generation                    
  
    //   begin  
    //     // single write transaction with fully randomization
    //      multiple_write_transaction_full_rand ("single write",1);
         
    //     mtestWID = $urandom_range(0,(1<<(0)-1)); 
    //     mtestWADDR = 0;
    //     mtestWBurstLength = 0;
    //     mtestWDataSize = xil_axi_size_t'(xil_clog2((32)/8));
    //     mtestWBurstType = XIL_AXI_BURST_TYPE_INCR;
    //     mtestWData = $urandom();
    //     //single write transaction filled in user inputs through API 
    //     single_write_transaction_api("single write with api",
    //                                  .id(mtestWID),
    //                                  .addr(mtestWADDR),
    //                                  .len(mtestWBurstLength), 
    //                                  .size(mtestWDataSize),
    //                                  .burst(mtestWBurstType),
    //                                  .wuser(mtestWUSER),
    //                                  .awuser(mtestAWUSER), 
    //                                  .data(mtestWData)
    //                                  );

    //     //multiple write transactions with the same inline randomization 
    //     multiple_write_transaction_partial_rand(.num_xfer(2),
    //                                             .start_addr(mtestWADDR),
    //                                             .id(mtestWID),
    //                                             .len(mtestWBurstLength),
    //                                             .size(mtestWDataSize),
    //                                             .burst(mtestWBurstType),
    //                                             .no_xfer_delays(1)
    //                                            );
    //   end
 
    //   begin
    //     //single read transaction with fully randomization
    //     multiple_read_transaction_full_rand ("single read",1);

    //     mtestRID = $urandom_range(0,(1<<(0)-1));
    //     mtestRADDR = $urandom_range(0,(1<<(32)-1));
    //     mtestRBurstLength = 0;
    //     mtestRDataSize = xil_axi_size_t'(xil_clog2((32)/8)); 
    //     mtestRBurstType = XIL_AXI_BURST_TYPE_INCR;
    //     //single read transaction filled in user inputs through API 
    //     single_read_transaction_api("single read with api",
    //                                  .id(mtestRID),
    //                                  .addr(mtestRADDR),
    //                                  .len(mtestRBurstLength), 
    //                                  .size(mtestRDataSize),
    //                                  .burst(mtestRBurstType)
    //                                  );
    //     //multiple read transaction with the same inline randomization 
    //     multiple_read_transaction_partial_rand( .num_xfer(2),
    //                                             .start_addr(mtestRADDR),
    //                                             .id(mtestRID),
    //                                             .len(mtestRBurstLength),
    //                                             .size(mtestRDataSize),
    //                                             .burst(mtestRBurstType),
    //                                             .no_xfer_delays(1)
    //                                            ); 
    //     //get read data back from driver
    //     rd_trans = agent.rd_driver.create_transaction("read transaction with randomization for getting data back");
    //     fill_transaction_with_fully_randomization(rd_trans);
    //     //get read data beat back from driver
    //     get_rd_data_beat_back(rd_trans,Rdatabeat);
    //     //get read data block back from driver
    //     get_rd_data_block_back(rd_trans,Rdatablock);
    //   end  
    // join


endmodule 

