# ECE532 DCT Compressor

This is a project that our team (Team HEALTH) built for ECE532 in Spring 2021 at the University of Toronto. The goals of this project were to:

1. Compress images sent over UART from the PC to FPGA1
2. Send the compressed coefficients over TCP to FPGA2
3. Decompress the image and send it back to the PCA via TCP

We only got about ~2/3 of that working by the end of the project, but hopefully this code serves as a good starting point for similar implementations.

## Project Introduction
You can find all of our presentations and our final report in the `docs` folder. This is a great starting point if you're looking to learn more about the project, what our goals were, and how far we got with the project.

## File Structure

The overall file structure of this project is as follows. A brief description of each of the folders is provided below

``` bash
├───docs
├───figures
├───fpga
│   ├───axis_custom_dct
│   ├───sd_card
│   └───tb_axis_custom_dct
├───microblaze
│   ├───compression-main
│   ├───compression-main2
│   ├───mirror-server
└───python
```

### docs
Contains our project presentations and final report, for reference.

### figures
Contains some figures used in this README.

### fpga 
This folder contains all FPGA-related modules that we built for the project. Specifically, there is a dedicated `axis_custom_dct` and `sd_card` folder related to all the DCT and SD card modules, respectively. There is also a `tb_axis_custom_dct` folder which contains the block diagram and simulation files for performing a test of the custom DCT module using the Xilinx AXI VIP. 

#### axis_custom_dct

Contains all of our source code, test benches, and memory files for our implementation of a DCT compressor accessed over AXI-Stream. The source code spans several modules, with each module having a 2-in, 2-out interface with input and output valid flags. The modules will register input when the input is valid, and will signal valid output when the output is valid. No handshaking takes place, so the downstream module either needs to be able to handle two values per cycle or have sufficient buffer size. There are a couple of test benches for the key modules. that can be used to check that everything is working properly.

The design also uses two Xilinx FIFOs, which are Xilinx IP. The `ip_repo` contains the compiled module (so that the IP works), but you'll have to re-generate it yourself if you want to modify something.

The AXI-Stream interface assumes that you have a 16-bit data bus transferring the first pixel in the lower 8-bits and the second pixel in the upper eight bits. This was done because the DCT modules take two inputs per cycle. The output is a 32-bit wide bus, with the lower 16 bits being the first encoded coefficient and the upper 16 bits being the second. The run-length encoding scheme is as follows:

**Zero Packets**

```
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|                Zero Packet                    |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|1 | Zero Count      |             0            |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
```

Bit 15 being set to 1 indicates that the packet is a zero. Bits `[14:9]` indicate the number of zeros, and a value of 0b000000 indicates that there are 64 zeros (the value wraps around). The lower 9 bits `[8:0]` are currently unused and set to zero. A [Huffman coding](https://en.wikipedia.org/wiki/Huffman_coding) scheme would pack these coefficients a lot more tightly 

**Non-Zero Packets**

```
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|              Non-Zero Packet                  |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|0 |X |           Non-zero number               |
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+

```

Bit 15 being set to 0 indicates that the packet is non-zero. Bit 14 is currently don't-care (at least in our 14-bit coefficient implementation) and bits `[13:0]` are the signed coefficient value. In this case, bit 13 is the sign bit, and requires appropriate conversion on the decompression side.

#### sd_card

Contains all of our source code for the SD card interface module. The original Verilog module was taken from [Introductory Digital Systems Laboratory (6.111)](http://web.mit.edu/6.111/www/f2015/tools/sd_controller.v) at MIT, and is included in the `original_code` repo. We've also created an AXI interface for the block, and wired it all together in `sd_control_ram_v1_0.v`.

#### tb_axis_custom_dct

This folder contains a block diagram and simulation files that we created for testing the DCT module with the complete AXI Stream interface. The Xilinx AXI DMA block is used to send and receive AXI Stream from the DCT module, and the Xilinx AXI VIP block is used to exercise the module.

As before, you'll have to have access to the relevant Xilinx IP if you'd like to re-create the block diagram exactly. We've included a photo of the block diagram below for reference:

![A screenshot of the block diagram we created for testing the AXI Stream interface of our DCT module][tb_bd]

[tb_bd]: figures/tb_axis_custom_dct.png

### microblaze

#### Compression-main

This folder contains all the source code (in C) for the first program uploaded to FPGA#1 Microblaze microprocessor. It receives hyperspectral images from the Host PC via UART and stores them into SD card.

UART is set to baud rate 115200 in hardware. Writing to SD card is the most time consuming operation, takes about 0.8 seconds per write.

#### Compression-main2

(Sorry for the bad naming scheme)

This folder contains all the source code (in C) for the second program uploaded to FPGA#1 Microblaze microprocessor. It reads the image pixel intensities from SD card, pass them to DCT for compression, and read back the coefficients. It then assembles coefficients into a custom packet format and sends them to FPGA#2 over TCP.

The DCT FIFO streaming interface is currently not functioning fully, so the coefficients read back are not correct. Otherwise the data pipeline was tested to be functional.

#### Mirror-Server

This folder contains all the source code (in C) for FPGA#2. This FPGA acts as a TCP packet mirror server. It receives the packets from one client and stores them in memory, depending on the client request type defined in the first byte in a message. Later when another client connects and request receiving the packets, the server will send the packet it stored in memory without change. Thus the name "mirror", since it sends and receives packets with no decoding or modification.

This requires the EthernetLite IP in hardware, and is mostly inspired from the LwIP library and HTTP-server example provided by Xilinx. 

### python

Over the course of the project we created a lot of Python scripts to either generate memory files, test the network interface, or test the DCT algorithm itself. This folder contains the complete set of these scripts, along with a test image. The test image comes from the Columbia University [CAVE Multispectral Image Database](https://www.cs.columbia.edu/CAVE/databases/multispectral/).

Perhaps the most important to using the DCT block itstelf would be `coeff_gen.py` and `quantization_gen.py`. These are needed for re-generating the DCT coefficients and quantization bit-shifts. The `host-pc-uart.py` file is used for transferring data to FPGA1 over UART, and the `pc-client.py` file is used for receiving the run-length encoded coefficients. 

## Usage

( include the customization parameters for the different blocks )


## Contributions & Support

We will likely not be actively maintaining this project moving forwards, but you're welcome to send us any questions you have regarding the code. We will also not be accepting any external pull requests.

## Authors & Acknowledgement

Team HEALTH is:
- Brytni Richards
- Dylan Vogel
- Lorna (Xi) Lan

## License
[MIT](https://choosealicense.com/licenses/mit/)


