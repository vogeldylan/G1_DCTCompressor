/* Header file for dct_fifo.c, a collection of utilities to handle
 * reading/writing from the AXI STREAM FIFO for DCT operation.
 *
 * Author: Dylan vogel
 * Last Modified: 2021-03-30
 *
 */

#ifndef DCT_FIFO_H_
#define DCT_FIFO_H_

#include "xil_exception.h"
#include "xstreamer.h"
#include "xil_cache.h"
#include "xllfifo.h"
#include "xstatus.h"
#include "xparameters.h"
//#include "xil_printf.h"

/* DEFINES */

#define FIFO_DEV_ID             XPAR_AXI_FIFO_0_DEVICE_ID
#define MAX_FIFO_LEN            512 // bytes, set in block diagram
// #define FIFO_BASE_ADDR          XPAR_AXI


/* Function Definitions */
int dct_init(void);
int dct_transmit(u8 *base_addr, u32 len);
int dct_transmit_done(void);
u32 dct_receive(u16 *dest_addr);

#endif // DCT_FIFO_H_
