/*
 * sd_card.h
 *
 *  Created on: Mar 16, 2021
 *      Author: richa513
 */

#ifndef SRC_SD_CARD_H_
#define SRC_SD_CARD_H_
#include <stdio.h>
#include "platform.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "sleep.h"

#define SD_CARD_ADDR	0x44A10000
#define SPI_SD_ADDR		0x44A00000
#define SD_CMD_REG		0
#define SD_STATUS_REG	4
#define SD_ADDR_REG		8 //SD card write/read address
#define SD_DEBUG_REG	12 //SD card state
#define SD_WRITE_REG	16 //Data to write to SD card
#define SD_RD_DATA_REG	20 //Data read from SD card
//#define SD_CLOCK		24 //SD card clock
#define SD_RAM_CMD_REG	24 //Temp RAM storage commands
#define SD_WADDR_REG	28
#define SD_RADDR_REG	32

// CMD register macros
#define CMD_RESET		0b1
#define CMD_WRITE		0b10
#define CMD_READ		0b100
// RAM CMD register macros
#define CMD_RAM_WRITE	0b10
#define CMD_RAM_READ	0b100

//Writes to AXI register - Base address assumed to be in xparameters
#define XSPI_AXI_WRITE(address, data) \
	Xil_Out32((SPI_SD_ADDR) + (address), (data))
//Reads from AXI register
#define XSPI_AXI_READ(address) \
	Xil_In32((SPI_SD_ADDR) + (address))

void sd_write(u32 addr, int len, u8* data_arr);
void sd_read(u32 addr, int len, u8* ret_data_arr);
void sd_card_test();
void sd_card_reset();
#endif /* SRC_SD_CARD_H_ */
