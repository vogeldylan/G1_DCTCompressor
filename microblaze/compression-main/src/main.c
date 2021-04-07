/******************************************************************************
*
* Copyright (C) 2009 - 2017 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/* =============================================================================
 *  INCLUDES
 * ===========================================================================*/

//Standard library includes
#include <stdio.h>
#include <string.h>
// #include <time.h>

// UART files
#include "uart.h"
#include "xuartlite.h"

//BSP includes for peripherals
#include "xparameters.h"
#include "netif/xadapter.h"

//DMA files
#include "xil_printf.h"
//#include "xaxidma.h"
#include "xdebug.h"
#include "sleep.h"
//#include "dct_dma.h"
#include "dct_fifo.h"
#include "sd_card.h"

// need to get platform.h, platform_config.h from the example project to include
#include "platform.h"
#include "platform_config.h"
#if defined (__arm__) || defined(__aarch64__)
#include "xil_printf.h"
#endif
#include "xil_cache.h"

//LWIP include files
#include "lwip/ip_addr.h"
#include "lwip/tcp.h"
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "lwip/inet.h"
#include "lwip/etharp.h"
#if LWIP_IPV6==1
#include "lwip/ip.h"
#else
#if LWIP_DHCP==1
#include "lwip/dhcp.h"
#endif
#endif

/* =============================================================================
 *  DEFINES
 * ===========================================================================*/

#define SRC_MAC_ADDR {0x00, 0x0a, 0x77, 0x03, 0x03, 0x04}
#define SRC_IP4_ADDR "1.1.1.2"
#define IP4_NETMASK "255.255.0.0"
#define IP4_GATEWAY "1.1.0.1"
#define SRC_PORT 50000

#define DEST_IP4_ADDR  "1.1.1.1"
#define DEST_IP6_ADDR "fe80::6600:6aff:fe71:fde3"
#define DEST_PORT 7

// 8x8x7 block numbers sent over UART
// 146 8x8x7 blocks + 2 left over with zero padding
#define IMG_BLOCK_NUM 1024
#define UART_BLOCK_NUM 147

#define TCP_SEND_BUFSIZE 134
#define BYPASS_DCT 0

//Interrupt handlers
#define INTC_DEVICE_ID XPAR_INTC_0_DEVICE_ID
#define UARTLITE_INT_IRQ_ID XPAR_INTC_0_UARTLITE_0_VEC_ID
#define EMACLITE_INT_IRQ_ID XPAR_INTC_0_EMACLITE_0_VEC_ID
#define TIMER_INT_IRQ_ID XPAR_INTC_0_TMRCTR_0_VEC_ID

/* binary printing */

#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c"
#define BYTE_TO_BINARY(byte)       \
    (byte & 0x80 ? '1' : '0'),     \
        (byte & 0x40 ? '1' : '0'), \
        (byte & 0x20 ? '1' : '0'), \
        (byte & 0x10 ? '1' : '0'), \
        (byte & 0x08 ? '1' : '0'), \
        (byte & 0x04 ? '1' : '0'), \
        (byte & 0x02 ? '1' : '0'), \
        (byte & 0x01 ? '1' : '0')


/* =============================================================================
 *  FUNCTION PROTOTYPES
 * ===========================================================================*/

void lwip_init(); /* missing declaration in lwIP */


#if LWIP_IPV6==1
void print_ip6(char *msg, ip_addr_t *ip);
#else
void print_ip(char *msg, ip_addr_t *ip);
void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);
#endif

void assemble_packets(u8* packet_ptr, u8* coeff_ptr, u32 len, u8 type);


/* =============================================================================
 *  VARIABLES AND GLOBALS
 * ===========================================================================*/

//DHCP global variables
#if LWIP_IPV6==0
#if LWIP_DHCP==1
extern volatile int dhcp_timoutcntr;
err_t dhcp_start(struct netif *netif);
#endif
#endif

//Networking global variables
extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
static struct netif server_netif;
struct netif *app_netif;
static struct tcp_pcb *c_pcb;
char is_connected;
struct netif *echo_netif;

//Packet input global variables for TCP
u8 packetinput[TCP_SEND_BUFSIZE] = {0};

// array to store the coefficients to be written out over TCP
u8 coeff_arr[IMG_BLOCK_NUM][134] = {0};

int packet_sent = 0;

// dct global arrays
u16 dct_rx_ptr[65] = {0}; // array for storing the DCT output

u32 telem_num = 0;

u8 telem_ratio[134] = {0};
u8 telem_bw[134] = {0};

// dct_tx_ptr is the same as &dct_tx_ptr[0], reminder to myself

/* =============================================================================
 *  FUNCTIONS
 * ===========================================================================*/

int main()
{

    /*
     * UART RECEIVE IMAGE HERE
     */

    init_platform();

    //Set up the UART and configure the interrupt handler for bytes in RX buffer
    SetupUartLiteNoInterrupt(UARTLITE_DEVICE_ID);

	platform_enable_interrupts();

	//Get a reference pointer to the Uart Configuration
	UartLite_Cfg = XUartLite_LookupConfig(UARTLITE_DEVICE_ID);

	//Print out the info about our XUartLite instance
	xil_printf("\n\r");
	xil_printf("Serial Port Properties\n");
	xil_printf("Device ID : %d\n", UartLite_Cfg->DeviceId);
	xil_printf("Baud Rate : %d\n", UartLite_Cfg->BaudRate);
	xil_printf("Data Bits : %d\n", UartLite_Cfg->DataBits);
	xil_printf("Base Addr : %08X\n", UartLite_Cfg->RegBaseAddr);
	xil_printf("\n\r");

	// UART OPERATION
	for(u32 i=0; i<UART_BLOCK_NUM; i++){
		xil_printf("Waiting to receive UART packets\n");
		uart_sd((u32)(0x00000000 + i));
		xil_printf("\nimage block %d wrote to SD card\n\n", i);

		sleep(1);
		SendBuffer[0] = 33; // ASCII !
		XUartLite_Send(&UartLite, &SendBuffer[0],1);
		resetBuffer();
	}

    cleanup_platform();

    return 0;

}
