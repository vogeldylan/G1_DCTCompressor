/*
 * main.c: simple dma-only test application for exercising the DCT block in hardware
 *
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
// #include "xaxidma.h"
#include "xdebug.h"
#include "sleep.h"
#include "dct_fifo.h"
// #include "dct_dma.h"

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


// to demonstrate two-wide block transfers
u8 tx_ptr[128] = {0};
u16 rx_ptr[128] = {0};

/* function prototypes */
int main_ex_dct(void);
int test_dct(void);

int main_ex_dct()
{
    init_platform();

    xil_printf("Starting ....\n");
    test_dct();

    cleanup_platform();
    return 0;
}

int test_dct(void)
{

    u32 rx_len;

    // test block from pompom
    int test_arr[64] = {104, 103, 102, 97, 95, 94, 95, 94,
                        107, 105, 103, 99, 97, 97, 96, 95,
                        111, 109, 108, 105, 104, 103, 100, 97,
                        113, 109, 108, 106, 106, 103, 103, 99,
                        109, 109, 108, 107, 106, 109, 106, 104,
                        115, 112, 111, 109, 107, 110, 109, 105,
                        114, 114, 112, 109, 109, 111, 111, 105,
                        117, 117, 116, 113, 112, 110, 106, 104};

    // not accurate because of bit width
    int check_arr[64] = {-11, 3, 0, 0, 0, 0, 0, 0,
                         -2, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0};

    // write test pixel values
    for (int i = 0; i < 128; i = i + 1)
    {
        // repeats the block twice in memory
        tx_ptr[i] = test_arr[(i%64)];
        // xil_printf("tx_ptr %d: %d\n", i, *(tx_ptr + i));
    }


    dct_init();
    xil_printf("Transmitting to fifo ...\n");
    dct_transmit((u8*)tx_ptr, 128);
    xil_printf("Waiting for fifo ... \n");
    while (!dct_transmit_done()) {};

    // note that rx_ptr is now 16-bit for simplicity
    rx_len = dct_receive((u16*)rx_ptr);

    xil_printf("Done(?) FIFO transfers");
    xil_printf("Got transfer length of: %d\n", rx_len);

    xil_printf("Coefficient data:\n");
    for (int i = 0; i < rx_len; i = i + 1)
    {
        // NOTE FOR LORNA:
        //  Here I am reading 16-bit coefficient values because rx_ptr is 16-bit
        //  Depending on how you need to send it to lwip, you may need to do
        //  something different
        xil_printf("Got %x\n", rx_ptr[i]);
    	// xil_printf("Got %x, expected %x\n", rx_ptr[i], check_arr[i]);
        // xil_printf("ERROR: expected coeff %x at index %d, got %x\n", check_arr[i], i, rx_ptr[i]);
    }

    xil_printf("Done reading coefficients\n");

    return 0;
}
