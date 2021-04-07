#include "sd_card.h"

// Write to SD card
// addr: SD card address to write to
// len: length of array to write
// data_arr: data to write as an array
// Restrictions:
// 1. each element can only be 8 bytes
// 2. maximum write amount is 511
void sd_write(u32 addr, int len, u8* data_arr) {
	print("Write to SD card \n");
	// Write to RAM
	for (u16 i=0; i<len; i++) {
		if (i < 10){
			xil_printf("SD write data %d\n", *(data_arr+i));
		}
		//RAM address location
		XSPI_AXI_WRITE(SD_WADDR_REG, i);
		//Data to write
		XSPI_AXI_WRITE(SD_WRITE_REG, data_arr[i]);
		//Actually write
		XSPI_AXI_WRITE(SD_RAM_CMD_REG, CMD_RAM_WRITE);
		//Stop writing
		XSPI_AXI_WRITE(SD_RAM_CMD_REG, 0);
	}
	XSPI_AXI_WRITE(SD_WRITE_REG, 0xaa);
	// Actually write to SD card
	// Don't do anything until idle
	while(XSPI_AXI_READ(SD_DEBUG_REG) != 6);
	// Set up write conditions - address
	XSPI_AXI_WRITE(SD_ADDR_REG, addr);
	// Start write process
	XSPI_AXI_WRITE(SD_CMD_REG, CMD_WRITE);
	// Stop sending write signal
	while(XSPI_AXI_READ(SD_DEBUG_REG) == 6);
	XSPI_AXI_WRITE(SD_CMD_REG, 0x0);
}

// Note: Ignore first element of returned array
// addr: SD card address to read from
// len: length of read
// ret_data_arr: empty array that will be filled with sd card returned data
void sd_read(u32 addr, int len, u8* ret_data_arr) {
	print("Read from SD card \n");
	len = len + 1;
	// Command SD card to read
	XSPI_AXI_WRITE(SD_ADDR_REG, addr);
	while(XSPI_AXI_READ(SD_DEBUG_REG) != 6){
		//xil_printf("read state %d\n", XSPI_AXI_READ(SD_DEBUG_REG));
	}
	// Don't do anything until idle
	XSPI_AXI_WRITE(SD_CMD_REG, CMD_READ);
	usleep(500);
	// Wait until read done
	while(XSPI_AXI_READ(SD_DEBUG_REG) != 6){
		//xil_printf("read state2 %d\n", XSPI_AXI_READ(SD_DEBUG_REG));
	}
	// From RAM
	//xil_printf("about to read from RAM\n");
	for (u16 i=1; i<len; i++) {
		//RAM address location
		XSPI_AXI_WRITE(SD_RADDR_REG, i);
		//Tell to read
		XSPI_AXI_WRITE(SD_RAM_CMD_REG, CMD_RAM_READ);
		//Read data
		ret_data_arr[i-1] = XSPI_AXI_READ(SD_RD_DATA_REG);
		if ((i-1) < 10){
			xil_printf("SD read data %d\n", ret_data_arr[i-1]);
		}

		//Stop reading
		XSPI_AXI_WRITE(SD_RAM_CMD_REG, 0);
	}
	// End read
	XSPI_AXI_WRITE(SD_RAM_CMD_REG, 0x0);
	//print("Done read\n");
}

void sd_card_reset(){

	// print("\n\nSD test run\r");
    // Reset SD card - set bit 0 of reg 0 high
    XSPI_AXI_WRITE(SD_CMD_REG, CMD_RESET);
    //u32 reg = XSPI_AXI_READ(SD_CMD_REG);
    // xil_printf("Status reg set to: %d\n", reg);
    // sleep(1);
    // xil_printf("Debug state: %d\n", XSPI_AXI_READ(SD_DEBUG_REG));
    //Set reset back low
    XSPI_AXI_WRITE(SD_CMD_REG, 0x00);
    //reg = XSPI_AXI_READ(SD_CMD_REG);
    //xil_printf("Status reg set to: %d\n", reg);
    print("reset SD card\n");

}


void sd_card_test()
{
    init_platform();

    sd_card_reset();

    xil_printf("Initialize testing array:");
    int data_arr[10];
    int arr_size = 15;
    for (int i=0; i<arr_size; i++) {
    	data_arr[i] = i + 7;
    	xil_printf("%x ", data_arr[i]);
    }
    xil_printf("\n");
    sd_write(0x10, arr_size, data_arr);

    int ret_arr[arr_size];
    sd_read(0x10, arr_size, ret_arr);

    xil_printf("Returned array:");
        // ignore first array value though
        for (int i=0; i<(arr_size+1); i++) {
    		xil_printf("%x ", ret_arr[i]);
    	}
        xil_printf("\n");

    // second write
	xil_printf("Initialize testing array:");
	for (int i=0; i<arr_size; i++) {
		data_arr[i] = i + 10;
		xil_printf("%x ", data_arr[i]);
	}
	xil_printf("\n");

	sd_write(0x11, arr_size, data_arr);

    sd_read(0x11, arr_size, ret_arr);
    xil_printf("Returned array:");
    // ignore first array value though
    for (int i=0; i<(arr_size+1); i++) {
		xil_printf("%x ", ret_arr[i]);
	}
    xil_printf("\n");

    cleanup_platform();
}

void sd_write_old() {
	print("About to write to SD card \n");
	u32 len = 50;
	u32 addr = 0x10;
	// Set up write conditions
	XSPI_AXI_WRITE(SD_ADDR_REG, addr);
	XSPI_AXI_WRITE(SD_WRITE_REG, 0x11b); //beginning value
	// Don't do anything until idle
	while(XSPI_AXI_READ(SD_DEBUG_REG) != 6);
	// Start write process
	XSPI_AXI_WRITE(SD_CMD_REG, CMD_WRITE);
	// Stop sending write signal
	while(XSPI_AXI_READ(SD_DEBUG_REG) == 6);
	XSPI_AXI_WRITE(SD_CMD_REG, 0x0);
	for (u16 i=0; i<len; i++) {
		//while writing value, don't interrupt
		while(XSPI_AXI_READ(SD_DEBUG_REG) != 17);
		XSPI_AXI_WRITE(SD_WRITE_REG, i); //write new value
		while(XSPI_AXI_READ(SD_DEBUG_REG) == 17);
	}
	XSPI_AXI_WRITE(SD_WRITE_REG, 0xaa);
}

void sd_read_old() {
	print("About to read from SD card \n");
	u32 len = 50;
	u32 addr = 0x10;
	u32 read_arr[len];
	// Set up read conditions
	XSPI_AXI_WRITE(SD_ADDR_REG, addr);
	// Don't do anything until idle
	while(XSPI_AXI_READ(SD_DEBUG_REG) != 6);
	XSPI_AXI_WRITE(SD_CMD_REG, CMD_READ);
	for (u16 i=0; i<len; i++) {
		//wait for value to appear
		while(XSPI_AXI_READ(SD_DEBUG_REG) != 13);
		read_arr[i] = XSPI_AXI_READ(SD_RD_DATA_REG);
		while(XSPI_AXI_READ(SD_DEBUG_REG) == 13);
	}
	// End read
	XSPI_AXI_WRITE(SD_CMD_REG, 0x0);
	for (u16 i=0; i<len; i++) {
		xil_printf("%x ", read_arr[i]);
	}
}
