/*
 * Copyright (C) 2009 - 2018 Xilinx, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 */

//Standard library includes
#include <stdio.h>
#include <string.h>

//BSP includes for peripherals
#include "xparameters.h"
#include "netif/xadapter.h"

// include lwip stuff
#include "lwip/tcp.h"
#include "lwip/err.h"
#include "xil_printf.h"


// function calls
int transfer_data();
void print_app_header();
enum req_type decode_request(char *req, int l);
int do_404(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen);
int do_send(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen);
int ack_send(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen);
int do_receive(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen);
void dump_payload(char *p, int len);
int generate_response(struct tcp_pcb *pcb, struct pbuf *p, char *payload, int len);
err_t recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err);
err_t accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err);
int start_application();

// message type definition
// R - receive message and write to memory
// S - send message from the remembered array
enum req_type {RECV, SEND, UNKNOWN};

unsigned ipv4_port = 7;

#define MAX_PKT_NUM 2048 // expected block coefficients + 1
// based on our own packet definition
int curr_coeff_packet = 0;

// place to store the packets
u8 packet_buffer[MAX_PKT_NUM][134];
int packet_len_buffer[MAX_PKT_NUM];

volatile u16 curr_pkt_num = 0;
volatile u16 last_pkt_num = 0;
volatile u16 size_pkt_buf = 0;
volatile int packet_number = 0;

int transfer_data() {
	return 0;
}

void print_app_header()
{
#if (LWIP_IPV6==0)
	xil_printf("\n\r\n\r-----lwIP TCP mirror server ------\n\r");
#else
	xil_printf("\n\r\n\r-----lwIPv6 TCP echo server ------\n\r");
#endif
	xil_printf("TCP packets sent to port %d will be echoed back\n\r", ipv4_port);
}

enum req_type decode_request(char *req, int l){
	char *receive_str = "R";
	char *send_str = "S";

	if (!strncmp(req, receive_str, l)){
		return RECV;
	}

	if (!strncmp(req, send_str, l)){
		return SEND;
	}
	printf("Received package: %d\n", req[0]);
	return UNKNOWN;

}

int do_404(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen){
	xil_printf("Invalid message type! Closing connection\n");

	tcp_close(pcb);

	return 0;
}

int do_receive(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen){

	if (size_pkt_buf <= MAX_PKT_NUM){
		// copy the request to one of the free slots in the packet buffer
		xil_printf("copying the payload string\n");
		memcpy((u8 *)(packet_buffer[last_pkt_num]), (u8 *)req, rlen);
		packet_len_buffer[last_pkt_num] = rlen; // store the length of this packet

		// update the packet array pointers
		size_pkt_buf = size_pkt_buf + 1;
		last_pkt_num = (last_pkt_num + 1) % MAX_PKT_NUM;

		xil_printf("packet number %d, last packet number %d\n", size_pkt_buf, last_pkt_num);

		ack_send(pcb, p, req, rlen);

	} else {
		xil_printf("ERROR: Out of space in the packet buffer!\n");
		return 1;
	}

	return 0;
}

int do_send(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen){
	// declare err
	err_t err = ERR_OK;

	// send everything we have
	if (size_pkt_buf > 0) {
		// write out the current packet buffer address, of length of the packet (as we've stored it)
		// for(int i=0; i<(int)(packet_len_buffer[curr_pkt_num]); i++){
		//	xil_printf("sent packet %d\n", packet_buffer[curr_pkt_num][i]);
		//}
		err = tcp_write(pcb, (u8 *)(packet_buffer[curr_pkt_num]), (int)(packet_len_buffer[curr_pkt_num]), 1);

		// update the current packet number and buffer size
		curr_pkt_num = (curr_pkt_num + 1) % MAX_PKT_NUM;
		size_pkt_buf = size_pkt_buf - 1;

		// check for errors
		if (err != ERR_OK){
			xil_printf("ERROR (%d) sending payload data\n", err);
		}

		err= tcp_output(pcb);
		if (err != ERR_OK){
			xil_printf("ERROR (%d) sending buffer data\n", err);

		}
	}
	printf("Sent packet %d\n", packet_number);
	packet_number += 1;
	return err;
}

int ack_send(struct tcp_pcb *pcb, struct pbuf *p, char *req, int rlen){
	err_t err;

	// assemble the payload according to format
	char *packet = "RDY";

	err = tcp_write(pcb, packet, strlen(packet), 1);
	if(err != ERR_OK){
		xil_printf("error (%d) sending ack signal\r\n", err);
		tcp_close(pcb);
	}

	xil_printf("send ack\n");

	return 0;
}

/* Not entirely sure how this works, but will try it out */
void dump_payload(char *p, int len){
	int i, j;

	for (i = 0; i < len; i += 16) {
		for (j = 0; j < 16; j++)
			xil_printf("%c ", p[i+j]);
		xil_printf("\r\n");
		}
	xil_printf("total len = %d\r\n", len);
}

int generate_response(struct tcp_pcb *pcb, struct pbuf *p, char *payload, int len){

	enum req_type msg_type = decode_request(payload, 1);

	switch(msg_type){
	case RECV:
		return do_receive(pcb, p, payload, len);
	case SEND:
		// first connection with the second client, just acknowledgment
		return do_send(pcb, p, payload, len);
	default:
		dump_payload(payload, len);
		return do_404(pcb, p, payload, len);
	}
}


err_t recv_callback(void *arg, struct tcp_pcb *tpcb,
                               struct pbuf *p, err_t err)
{
	/* do not read the packet if we are not in ESTABLISHED state */
	if (!p) {
		tcp_close(tpcb);
		tcp_recv(tpcb, NULL);
		return ERR_OK;
	}

	/* indicate that the packet has been received */
	tcp_recved(tpcb, p->len);

	/* echo back the payload */
	/* in this case, we assume that the payload is < TCP_SND_BUF */
	/*if (tcp_sndbuf(tpcb) > p->len) {
		err = tcp_write(tpcb, p->payload, p->len, 1);
	} else
		xil_printf("no space in tcp_sndbuf\n\r");
	*/
	generate_response(tpcb, p, p->payload, p->len);

	/* free the received pbuf */
	pbuf_free(p);

	return ERR_OK;
}

err_t accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
	static int connection = 1;
	xil_printf("Connection number is %d\n", connection);
	/* just use an integer number indicating the connection id as the
	   callback argument */
	tcp_arg(newpcb, (void*)(UINTPTR)connection);

	/* set the receive callback for this connection */
	tcp_recv(newpcb, recv_callback);

	/* increment for subsequent accepted connections */
	connection++;

	return ERR_OK;
}


int start_application()
{
	struct tcp_pcb *pcb;
	err_t err;
	unsigned port = ipv4_port; // don't understand this

	/* create new TCP PCB structure */
	pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
	if (!pcb) {
		xil_printf("Error creating PCB. Out of Memory\n\r");
		return -1;
	}

	/* bind to specified @port */
	err = tcp_bind(pcb, IP_ANY_TYPE, port);
	if (err != ERR_OK) {
		xil_printf("Unable to bind to port %d: err = %d\n\r", port, err);
		return -2;
	}

	/* we do not need any arguments to callback functions */
	tcp_arg(pcb, NULL);

	/* listen for connections */
	pcb = tcp_listen(pcb);
	if (!pcb) {
		xil_printf("Out of memory while tcp_listen\n\r");
		return -3;
	}

	/* specify callback to use for incoming connections */
	tcp_accept(pcb, accept_callback);

	xil_printf("TCP echo server started @ port %d\n\r", port);

	return 0;
}
