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

#define SRC_MAC_ADDR {0x00, 0x0a, 0x77, 0x03, 0x03, 0x01}
#define SRC_IP4_ADDR "1.1.1.2"
#define IP4_NETMASK "255.255.0.0"
#define IP4_GATEWAY "1.1.0.1"
#define SRC_PORT 50000

#define DEST_IP4_ADDR  "1.1.5.2"
#define DEST_IP6_ADDR "fe80::6600:6aff:fe71:fde3"
#define DEST_PORT 7

// 8x8x7 block numbers sent over UART
// 146 8x8x7 blocks + 2 left over with zero padding
#define IMG_BLOCK_NUM 1024
#define UART_BLOCK_NUM 147

//#define IMG_BLOCK_NUM 70
//#define UART_BLOCK_NUM 10

#define TCP_SEND_BUFSIZE 134

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

int setup_client_conn();
void tcp_fasttmr(void);
void tcp_slowtmr(void);
static err_t tcp_client_connected(void *arg, struct tcp_pcb *tpcb, err_t err);
static err_t tcp_client_recv(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err);
static err_t tcp_client_sent(void *arg, struct tcp_pcb *tpcb, u16_t len);
static void tcp_client_err(void *arg, err_t err);
static void tcp_client_close(struct tcp_pcb *pcb);

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

volatile int packet_sent = 0;

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
    //Varibales for IP parameters
    #if LWIP_IPV6==0
        ip_addr_t ipaddr, netmask, gw;
    #endif

    //The mac address of the board. this should be unique per board
    unsigned char mac_ethernet_address[] = SRC_MAC_ADDR;

    //Network interface
    app_netif = &server_netif;

    /*
     * UART RECEIVE IMAGE HERE
     */

    init_platform();

	platform_enable_interrupts();

    // /* DCT OPERATION GOES HERE*/


	// initialize the DCT AXIS FIFO
	dct_init();


    // declare the array storing what's read from the SD card
	u8 sd_read_arr[UART_BUFFER_SIZE] = {0};
    u32 rx_len = 0;
    u32 total_len = 0;
    // u32 bw = 0;

	// we're using DCT

	for(u32 sd_block=0; sd_block<UART_BLOCK_NUM; sd_block++){
		// iterate over the SD card blocks

		// read data from the sd card
		sd_read((u32)(0x00000000 + sd_block), UART_BUFFER_SIZE, (u8*)sd_read_arr);
		xil_printf("\nReading Data from SD card, block %d\n\n", sd_block);

		//xil_printf("random data checking %d\n", sd_read_arr[33]);

		if (sd_block == UART_BLOCK_NUM - 1){
			// last iteration of UART block doesn't contain all 7 blocks
			int residual = IMG_BLOCK_NUM % 7;

			xil_printf("residual is %d\n", residual);

			if(residual > 0){
				for (u32 i=0; i<residual; i++){
					// double start = clock();
					dct_transmit((u8*)(sd_read_arr + (i*64)), 64);
					xil_printf("waiting for DCT...\n");
					while (!dct_transmit_done()){};

					// double end = clock();
					// returns the # of received coefficients, each coeff is 2 bytes
					rx_len = dct_receive((u16*)dct_rx_ptr);
					xil_printf("Got coefficient length of: %d\n", rx_len);

					 for (u32 k=0; k < 134; k++){
						// zero the coeff array, if desired
						coeff_arr[sd_block*7+i][k] = 0;
					 }

					// cast dct_rx_ptr into 8-bit, use rx_len*2 to copy the bytes
					assemble_packets((u8*)(coeff_arr[sd_block*7+i]), (u8*)dct_rx_ptr, rx_len*2, 0);

					xil_printf("Assembled packet %d, server type %c, msg type %d, length %d\n",
							sd_block*7+i, coeff_arr[sd_block*7+i][0], coeff_arr[sd_block*7+i][1], rx_len*2);
					total_len = total_len + rx_len*2;
					// bw = bw + (int) rx_len*2 / (end - start);

				}
				break;
			}
		}else{
		for(u32 i=0; i<7; i++){

			// iterate over the number of image blocks in each SD card block

			// double start = clock();
			//dct_transmit((u8*)(sd_read_arr + (i*64)), 64); // just transmit directly from SD card read block
			xil_printf("waiting for DCT...\n");
			dct_init();
			dct_transmit((u8*)(sd_read_arr + i*64), 64);
			while (!dct_transmit_done()){};


			// double end = clock();
			rx_len = dct_receive((u16*)dct_rx_ptr); // returns the # of received coefficients, each coeff is 2 bytes
			xil_printf("Got coefficient length of: %d\n", rx_len);

			 for (u32 k; k < 134; k++){
				// zero the coeff array, if desired
				coeff_arr[sd_block*7+i][k] = 0;
			 }

			 //xil_printf("random data checking %d\n", dct_rx_ptr[0]);

			// cast dct_rx_ptr into 8-bit, use rx_len*2 to copy the bytes
			assemble_packets((u8*)(coeff_arr[sd_block*7+i]), (u8*)dct_rx_ptr, rx_len*2, 0);


			xil_printf("Assembled packet %d, server type %c, msg type %d, length %d\n",
					sd_block*7+i, coeff_arr[sd_block*7+i][0], coeff_arr[sd_block*7+i][1], rx_len*2);


			total_len = total_len + rx_len*2;
			// bw = bw + (int) rx_len*2 / (end - start);
			}
		}

	}


	u8 compressed_ratio[134] = {0};

	int ratio = (int) IMG_BLOCK_NUM * 64 / total_len;
	xil_printf("Compression ratio is %d\n", ratio);
	// bw = (int) bw / IMG_BLOCK_NUM;

	int shift = 1;
	while ((ratio >> 8*shift) > 0){
		compressed_ratio[shift-1] = (u8) (ratio >> 8*shift) && 0xff;
		shift++;
		if (shift >= 130){
			xil_printf("compression ratio too big, number invalid\n!!");
			break;
		}
	}

	assemble_packets(telem_ratio, compressed_ratio, shift, 2);
	telem_num = 1;

	xil_printf("Assembled packet %d, server type %c, msg type %d, length %d\n", telem_num, telem_ratio[0], telem_ratio[1], shift);
	/*
	u8 arr[130] = {0};
	shift = 1;
	while ((bw >> 8*shift) > 0){
		arr[shift-1] = (u8) (bw >> 8*shift) && 0xff;
		shift++;
		if (shift >= 130){
			xil_printf("compression ratio too big, number invalid\n!!");
			break;
		}
	}

	assemble_packets(telem_bw, arr, shift, 1);
	telem_num ++;

	xil_printf("Assembled packet %d, server type %c, msg type %d, length %d\n", telem_num, telem_bw[0], telem_bw[1], shift);
	*/

	/*
	 * TCP TRANSFER BEGINS HERE
	 */

    //Defualt IP parameter values
#if LWIP_IPV6==0
#if LWIP_DHCP==1
    ipaddr.addr = 0;
	gw.addr = 0;
	netmask.addr = 0;
#else
    (void)inet_aton(SRC_IP4_ADDR, &ipaddr);
    (void)inet_aton(IP4_NETMASK, &netmask);
    (void)inet_aton(IP4_GATEWAY, &gw);
#endif
#endif

    //LWIP initialization
    lwip_init();
    xil_printf("LWIP initialized\n");

    //Setup Network interface and add to netif_list
#if (LWIP_IPV6 == 0)
    if (!xemac_add(app_netif, &ipaddr, &netmask,
                   &gw, mac_ethernet_address,
                   PLATFORM_EMAC_BASEADDR)) {
        xil_printf("Error adding N/W interface\n");
        return -1;
    }
#else
    if (!xemac_add(app_netif, NULL, NULL, NULL, mac_ethernet_address,
						PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\n");
		return -1;
	}
	app_netif->ip6_autoconfig_enabled = 1;

	netif_create_ip6_linklocal_address(app_netif, 1);
	netif_ip6_addr_set_state(app_netif, 0, IP6_ADDR_VALID);

#endif
    netif_set_default(app_netif);


    // platform_disable_interrupts();
    //platform_enable_interrupts();
    //xil_printf("re-enable interrupts\n");

    //Specify that the network is up
    netif_set_up(app_netif);

#if (LWIP_IPV6 == 0)
#if (LWIP_DHCP==1)
    /* Create a new DHCP client for this interface.
	 * Note: you must call dhcp_fine_tmr() and dhcp_coarse_tmr() at
	 * the predefined regular intervals after starting the client.
	 */
	dhcp_start(app_netif);
	dhcp_timoutcntr = 24;

	while(((app_netif->ip_addr.addr) == 0) && (dhcp_timoutcntr > 0))
		xemacif_input(app_netif);

	if (dhcp_timoutcntr <= 0) {
		if ((app_netif->ip_addr.addr) == 0) {
			xil_printf("DHCP Timeout\n");
			xil_printf("Configuring default IP of %s\n", SRC_IP4_ADDR);
			(void)inet_aton(SRC_IP4_ADDR, &(app_netif->ip_addr));
			(void)inet_aton(IP4_NETMASK, &(app_netif->netmask));
			(void)inet_aton(IP4_GATEWAY, &(app_netif->gw));
		}
	}

	ipaddr.addr = app_netif->ip_addr.addr;
	gw.addr = app_netif->gw.addr;
	netmask.addr = app_netif->netmask.addr;
#endif
#endif

    //Print connection settings
#if (LWIP_IPV6 == 0)
    print_ip_settings(&ipaddr, &netmask, &gw);
#else
    print_ip6("Board IPv6 address ", &app_netif->ip6_addr[0].u_addr.ip6);
#endif

    //Gratuitous ARP to announce MAC/IP address to network
    etharp_gratuitous(app_netif);

    //Setup connection
    setup_client_conn();

    //Event loop
    while (1) {
        //Call tcp_tmr functions
        //Must be called regularly
        if (TcpFastTmrFlag) {
            tcp_fasttmr();
            TcpFastTmrFlag = 0;
        }
        if (TcpSlowTmrFlag) {
            tcp_slowtmr();
            TcpSlowTmrFlag = 0;
        }

        //Process data queued after interrupt
        xemacif_input(app_netif);

        //ADD CODE HERE to be repeated constantly
        // Note - should be non-blocking
        // Note - can check is_connected global var to see if connection open
        // Get input from stdin

        // if get input from stdin here needs to be non-blocking/Interrupt based

    }

    //Never reached
    cleanup_platform();

    return 0;
}


#if LWIP_IPV6==1
void print_ip6(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf(" %x:%x:%x:%x:%x:%x:%x:%x\n",
			IP6_ADDR_BLOCK1(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK2(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK3(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK4(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK5(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK6(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK7(&ip->u_addr.ip6),
			IP6_ADDR_BLOCK8(&ip->u_addr.ip6));

}
#else
void print_ip(char *msg, ip_addr_t *ip)
{
    print(msg);
    xil_printf("%d.%d.%d.%d\n", ip4_addr1(ip), ip4_addr2(ip),
               ip4_addr3(ip), ip4_addr4(ip));
}

void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{

    print_ip("Board IP: ", ip);
    print_ip("Netmask : ", mask);
    print_ip("Gateway : ", gw);
}
#endif


int setup_client_conn()
{
    struct tcp_pcb *pcb;
    err_t err;
    ip_addr_t remote_addr;

    xil_printf("Setting up client connection\n");

#if LWIP_IPV6==1
    remote_addr.type = IPADDR_TYPE_V6;
	err = inet6_aton(DEST_IP6_ADDR, &remote_addr);
#else
    err = inet_aton(DEST_IP4_ADDR, &remote_addr);
#endif

    if (!err) {
        xil_printf("Invalid Server IP address: %d\n", err);
        return -1;
    }

    //Create new TCP PCB structure
    pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
    if (!pcb) {
        xil_printf("Error creating PCB. Out of Memory\n");
        return -1;
    }

    //Bind to specified @port
    err = tcp_bind(pcb, IP_ANY_TYPE, SRC_PORT);
    if (err != ERR_OK) {
        xil_printf("Unable to bind to port %d: err = %d\n", SRC_PORT, err);
        return -2;
    }

    //Connect to remote server (with callback on connection established)
    err = tcp_connect(pcb, &remote_addr, DEST_PORT, tcp_client_connected);
    if (err) {
        xil_printf("Error on tcp_connect: %d\n", err);
        tcp_client_close(pcb);
        return -1;
    }

    is_connected = 0;

    xil_printf("Waiting for server to accept connection\n");

    return 0;
}

static void tcp_client_close(struct tcp_pcb *pcb)
{
    err_t err;

    xil_printf("Closing Client Connection\n");

    if (pcb != NULL) {
        tcp_sent(pcb, NULL);
        tcp_recv(pcb,NULL);
        tcp_err(pcb, NULL);
        err = tcp_close(pcb);
        if (err != ERR_OK) {
            /* Free memory with abort */
            tcp_abort(pcb);
        }
    }
}

static err_t tcp_client_connected(void *arg, struct tcp_pcb *tpcb, err_t err)
{

	u8_t apiflags = TCP_WRITE_FLAG_COPY;

    if (err != ERR_OK) {
        tcp_client_close(tpcb);
        xil_printf("Connection error\n");
        return err;
    }

    xil_printf("Connection to server established\n");

    //Store state (for callbacks)
    c_pcb = tpcb;
    is_connected = 1;

    u8 packetinput[TCP_SEND_BUFSIZE] = {0};

    if(telem_num > 0){
		xil_printf("sending %d telemetry data\n", telem_num);

		memcpy((u8*)packetinput, (u8*)telem_ratio, TCP_SEND_BUFSIZE);

		telem_num = 0;

	}

	//Loop until enough room in buffer (should be right away)
	while (tcp_sndbuf(c_pcb) < TCP_SEND_BUFSIZE);

	//Enqueue some data to send
	err = tcp_write(c_pcb, /*changed here*/packetinput, TCP_SEND_BUFSIZE, apiflags);

	if (err != ERR_OK) {
		xil_printf("TCP client: Error on tcp_write: %d\n", err);
		return err;
	}

	err = tcp_output(c_pcb);
	// no hankshaking for now, tcp_output should do what we expect
	if (err != ERR_OK) {
		xil_printf("TCP client: Error on tcp_output: %d\n",err);
		return err;
	}

	//Print message
	xil_printf("sent packet\n");

    //Set callback values & functions
    tcp_arg(c_pcb, NULL);
	tcp_recv(c_pcb, tcp_client_recv);
	tcp_sent(c_pcb, tcp_client_sent);

    tcp_err(c_pcb, tcp_client_err);
    return ERR_OK;
}

static err_t tcp_client_recv(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
    //If no data, connection closed
    if (!p) {
        xil_printf("No data received\n");
        tcp_client_close(tpcb);
        return ERR_OK;
    }

    //ADD CODE HERE to do on packet reception

    //Print message
    xil_printf("Packet received, %d bytes\n", p->tot_len);

    //Print packet contents to terminal
    char* packet_data = (char*) malloc(p->tot_len);
    pbuf_copy_partial(p, packet_data, p->tot_len, 0); //Note - inefficient way to access packet data

    // RDY, 3 bytes
    if(packet_data[0] == 82 && packet_data[1] == 68 && packet_data[2] == 89 && packet_sent >= 0){

    	xil_printf("received packet %c%c%c\n", packet_data[0], packet_data[1], packet_data[2]);
    	u8_t apiflags = TCP_WRITE_FLAG_COPY;

		// CLIENT TODO HERE

		u8 packetinput[TCP_SEND_BUFSIZE] = {0};

		// send telemetry data first
		if(packet_sent < IMG_BLOCK_NUM){
			xil_printf("packet sent is %d\n", packet_sent);
			// send all coefficient data

			xil_printf("coefficient packet number to sent is %d\n", packet_sent);

			memcpy((u8*)packetinput, (u8*)(coeff_arr[packet_sent]), TCP_SEND_BUFSIZE);

			packet_sent++;


			//Loop until enough room in buffer (should be right away)
			while (tcp_sndbuf(c_pcb) < TCP_SEND_BUFSIZE);

			//Enqueue some data to send
			err = tcp_write(c_pcb, /*changed here*/packetinput, TCP_SEND_BUFSIZE, apiflags);

			if (err != ERR_OK) {
				xil_printf("TCP client: Error on tcp_write: %d\n", err);
				return err;
			}

			err = tcp_output(c_pcb);
			// no hankshaking for now, tcp_output should do what we expect
			if (err != ERR_OK) {
				xil_printf("TCP client: Error on tcp_output: %d\n",err);
				return err;
			}

			//Print message
			xil_printf("sent packet\n");

			//END OF ADDED CODE
    	    }else{
    	    	xil_printf("Very harmful\n");
    	    }
    	}else{
    		xil_printf("received packet %c%c%c\n", packet_data[0], packet_data[1], packet_data[2]);
    	}

    //END OF ADDED CODE

    //Indicate done processing
    tcp_recved(tpcb, p->tot_len);

    //Free the received pbuf
    pbuf_free(p);

    return 0;
}

static err_t tcp_client_sent(void *arg, struct tcp_pcb *tpcb, u16_t len)
{

	xil_printf("mostly harmless\n");

    return 0;
}

static void tcp_client_err(void *arg, err_t err)
{
    LWIP_UNUSED_ARG(err);
    tcp_client_close(c_pcb);
    c_pcb = NULL;
    xil_printf("TCP connection aborted\n");
}


/** 
 * Assemble TCP packet according to required format
 *
 * @param packet_ptr (u8*) pointer to the write address
 * @param coeff_ptr (u8*) pointer to the read address
 * @param len (u32) length of bytes to copy over
 * @param type (u8) type of packet, user-defined
 * 
 * @return
 *  - void 
 */
void assemble_packets(u8* packet_ptr, u8* coeff_ptr, u32 len, u8 type){

	packet_ptr[0] = 82;
	packet_ptr[1] = type;
	packet_ptr[2] = (u8) ((len>>8) & 0xff);
	packet_ptr[3] = (u8) (len & 0xff);

	memcpy((u8*)(packet_ptr + 4), (u8*)coeff_ptr, len);
}


