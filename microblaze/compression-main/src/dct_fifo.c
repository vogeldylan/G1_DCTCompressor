/* A set of functions to handle initilization and writing to the AXI STREAM FIFO
 * 
 * Abstracts away some complexity by making assumptions about what you want to
 * do. If you'd prefer to handle it yourself, feel free.
 * 
 * Author: Dylan vogel
 * Last Modified: 2021-03-30
 * 
 */

/* INCLUDES */
#include "dct_fifo.h"


/* GLOBALS */
XLlFifo_Config *dct_fifo_cfg;
XLlFifo  dct_fifo;

/* FUNCTIONS */

/** 
 * Initialize the AXI STREAM Fifo; Assumes we're using AXI FIFO 0
 * 
 * @return
 *      int: whether the operation was successful (0) or not (!=0)
 */ 

int dct_init(void){
    int status;

    status = XST_SUCCESS;

    // lookup the fifo config
    dct_fifo_cfg = XLlFfio_LookupConfig(FIFO_DEV_ID); // assume device ID
    if (!dct_fifo_cfg) {
		xil_printf("No config found for %d\r\n", FIFO_DEV_ID);
		return XST_FAILURE;
	}

    // initialize the config
    status = XLlFifo_CfgInitialize(&dct_fifo, dct_fifo_cfg, dct_fifo_cfg->BaseAddress);
    if (status != XST_SUCCESS){
        xil_printf("Initialization failed \n");
        return status;
    }

    // check that the status register is cleared
	status = XLlFifo_Status(&dct_fifo);
	XLlFifo_IntClear(&dct_fifo,0xffffffff);
	status = XLlFifo_Status(&dct_fifo);
	if(status != 0x0) {
		xil_printf("\n ERROR : Reset value of ISR0 : 0x%x\t"
			    "Expected : 0x0\n\r",
			    XLlFifo_Status(&dct_fifo));
		return XST_FAILURE;
	}

	return status;
}

/**
 * Write the pixel values to the AXI Stream FIFO
 *
 * @param base_addr (u8*) pointer to the base address to read from
 * @param len (u32) length of data to read in bytes
 * 
 * @return
 *  -XST_SUCCESS to indicate success
 *  -XST_FAILURE to indicate FAILURE
 */ 
int dct_transmit(u8 *base_addr, u32 len){
    int status = XST_SUCCESS;
    u32 write_val = 0;

    xil_printf("in DCT block!!!!\n");

    if (len > MAX_FIFO_LEN){
        xil_printf("ERROR: attempting to write more bytes to the AXIS FIFO then there is space for ...");
    }

    for (int i=0 ; i < len ; i=i+2){
        // construct the word to write
        write_val =  (u32)(0x0000FFFF & (base_addr[1 + i] << 8 | base_addr[0 + i]));

        xil_printf("writing to DCT %d\n", write_val);
        // check for vacancy in the fifo tx buffer
        if (XLlFifo_iTxVacancy(&dct_fifo)){
            // write the 32-bit value
            XLlFifo_TxPutWord(&dct_fifo, write_val);
        } else {
            status = XST_FAILURE;
            xil_printf("AXIS FIFO is out of room, skipping pixel values");
        }
    }

    // write the length that we just wrote
    XLlFifo_iTxSetLen(&dct_fifo, len*2);

    return status;
}

/**
 * Check if the AXIS FIFO is done transmitting data
 * 
 * @return
 *  -0 to indicate not done
 *  -1 to indicate done
 */ 
int dct_transmit_done(void){

	xil_printf("in DCT transmit block!!!!\n");
    // check if done
    if (XLlFifo_IsTxDone(&dct_fifo)){
        return 1;
    }
    return 0;
}

/**
 * Read the DCT coefficients from the  AXI Stream FIFO
 *
 * @param dest_addr (u16*) pointer to the destination address to write to
 * 
 * @return
 *  -length of data read
 */ 
u32 dct_receive(u16 *dest_addr){

	xil_printf("in DCT receive block!!!!\n");
    int status;
    u32 rx_word;
    u32 rx_len = 0;

    while(XLlFifo_iRxOccupancy(&dct_fifo)){
        rx_len = XLlFifo_iRxGetLen(&dct_fifo)/2; // each coefficient is two bytes

        // read back the data
        for(int i=0; i < rx_len; i=i+2) {
            rx_word = XLlFifo_RxGetWord(&dct_fifo);
            // check that this order is correct
            dest_addr[i] = (u16)(rx_word & 0x0000FFFF); // lower coefficient
            dest_addr[i+1] = (u16)((rx_word >> 16) & 0x0000FFFF); // upper coefficient
        }
    }

    status = XLlFifo_IsRxDone(&dct_fifo);
    if (status != TRUE){
        xil_printf("Failing in receive complete ...\n");
    }
    
    return rx_len;

}


