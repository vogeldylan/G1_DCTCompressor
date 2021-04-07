# Microblaze Files

### Compression-main

This folder contains all the source code (in C) for the first program uploaded to FPGA#1 Microblaze microprocessor. It receives hyperspectral images from the Host PC via UART and stores them into SD card.



UART is set to baud rate 115200 in hardware. Writing to SD card is the most time consuming operation, takes about 0.8 seconds per write.

## Compression-main2

(Sorry for the bad naming scheme)

This folder contains all the source code (in C) for the second program uploaded to FPGA#1 Microblaze microprocessor. It reads the image pixel intensities from SD card, pass them to DCT for compression, and read back the coefficients. It then assembles coefficients into a custom packet format and sends them to FPGA#2 over TCP.

The DCT FIFO streaming interface is currently not functioning fully, so the coefficients read back are not correct. Otherwise the data pipeline was tested to be functional.

## Mirror-Server

This folder contains all the source code (in C) for FPGA#2. This FPGA acts as a TCP packet mirror server. It receives the packets from one client and stores them in memory, depending on the client request type defined in the first byte in a message. Later when another client connects and request receiving the packets, the server will send the packet it stored in memory without change. Thus the name "mirror", since it sends and receives packets with no decoding or modification.

This requires the EthernetLite IP in hardware, and is mostly inspired from the LwIP library and HTTP-server example provided by Xilinx. 

