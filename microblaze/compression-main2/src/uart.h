/***************************** Include Files *********************************/

#include "xparameters.h"
#include <xil_printf.h>
#include <stdio.h>
#include "xil_exception.h"
#include "xuartlite.h"
#include "xintc.h"
#include "xenv.h"
#include "platform.h"

/************************** Variable Definitions *****************************/

XUartLite UartLite; /* The instance of the UartLite Device */
XUartLite_Config *UartLite_Cfg; /* The instance of the UartLite Config */
XIntc InterruptController; /* The instance of the Interrupt Controller */

/************************** Constant Definitions *****************************/

/*
* The following constants map to the XPAR parameters created in the
* xparameters.h file. They are defined here such that a user can easily
* change all the needed parameters in one place.
*/
#define UARTLITE_DEVICE_ID XPAR_UARTLITE_0_DEVICE_ID
#define INTC_DEVICE_ID XPAR_INTC_0_DEVICE_ID
#define UARTLITE_INT_IRQ_ID XPAR_INTC_0_UARTLITE_0_VEC_ID


/*
* The following constant controls the length of the buffers to be sent
* and received with the UartLite device.
*/
#define UART_BUFFER_SIZE 256

/*
* The following counters are used to determine when the entire buffer has
* been sent and received.
*/
static volatile int TotalReceivedCount;
static volatile int TotalSentCount;

/*
* The following buffers are used in this example to send and receive data
* with the UartLite.
*/
u8 SendBuffer[1];
u8 ReceiveBuffer[UART_BUFFER_SIZE];
u8 BufferCopy[UART_BUFFER_SIZE];


/************************** Function Prototypes ******************************/

int SetupUartLite(u16 DeviceId);

int SetupUartLiteNoInterrupt(u16 DeviceId);

int SetupInterruptSystem(XUartLite *UartLitePtr);

void SendHandler(void *CallBackRef, unsigned int EventData);

void RecvHandler(void *CallBackRef, unsigned int EventData);

void uart_sd(u32 sd_addr);

void resetBuffer();


