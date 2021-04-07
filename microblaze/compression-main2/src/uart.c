#include "uart.h"
#include "sd_card.h"

/* Here are the pointers to the buffer */
u8* ReceiveBufferPtr = &ReceiveBuffer[0];
u8* SendBufferPtr = &SendBuffer[0];

/****************************************************************************/
/**
*
* This function does a minimal test on the UartLite device and driver as a
* design example. The purpose of this function is to illustrate
* how to use the XUartLite component.
*
* This function sends data and expects to receive the same data through the
* UartLite. The user must provide a physical loopback such that data which is
* transmitted will be received.
*
* This function uses interrupt driver mode of the UartLite device. The calls
* to the UartLite driver in the handlers should only use the non-blocking
* calls.
*
* @param DeviceId is the Device ID of the UartLite Device and is the
* XPAR_<uartlite_instance>_DEVICE_ID value from xparameters.h.
*
* @return XST_SUCCESS if successful, otherwise XST_FAILURE.
*
* @note
*
* This function contains an infinite loop such that if interrupts are not
* working it may never return.
*
****************************************************************************/
int SetupUartLite(u16 DeviceId)
{
	int Status;

	/*
	* Initialize the UartLite driver so that it's ready to use.
	*/
	Status = XUartLite_Initialize(&UartLite, DeviceId);
		if (Status != XST_SUCCESS) {
			return XST_FAILURE;
		}

    /*
    * Perform a self-test to ensure that the hardware was built correctly.
    */
    Status = XUartLite_SelfTest(&UartLite);
    if (Status != XST_SUCCESS) {
    	return XST_FAILURE;
    }

    /*
    * Connect the UartLite to the interrupt subsystem such that interrupts can
    * occur. This function is application specific.
    */
    Status = SetupInterruptSystem(&UartLite);
    if (Status != XST_SUCCESS) {
    	return XST_FAILURE;
    }

    /*
    * Setup the handlers for the UartLite that will be called from the
    * interrupt context when data has been sent and received, specify a
    * pointer to the UartLite driver instance as the callback reference so
    * that the handlers are able to access the instance data.
    */
    XUartLite_SetSendHandler(&UartLite, SendHandler, &UartLite);
    XUartLite_SetRecvHandler(&UartLite, RecvHandler, &UartLite);

    /*
    * Enable the interrupt of the UartLite so that interrupts will occur.
    */
    XUartLite_EnableInterrupt(&UartLite);

    return XST_SUCCESS;
}


int SetupUartLiteNoInterrupt(u16 DeviceId)
{
	int Status;

	/*
	* Initialize the UartLite driver so that it's ready to use.
	*/
	Status = XUartLite_Initialize(&UartLite, DeviceId);
		if (Status != XST_SUCCESS) {
			return XST_FAILURE;
		}

    /*
    * Connect the UartLite to the interrupt subsystem such that interrupts can
    * occur. This function is application specific.
    */
    /* Status = SetupInterruptSystem(&UartLite);
    if (Status != XST_SUCCESS) {
    	return XST_FAILURE;
    }*/

    /*
    * Setup the handlers for the UartLite that will be called from the
    * interrupt context when data has been sent and received, specify a
    * pointer to the UartLite driver instance as the callback reference so
    * that the handlers are able to access the instance data.
    */
    XUartLite_SetSendHandler(&UartLite, SendHandler, &UartLite);
    XUartLite_SetRecvHandler(&UartLite, RecvHandler, &UartLite);

    /*
    * Enable the interrupt of the UartLite so that interrupts will occur.
    */
    XUartLite_EnableInterrupt(&UartLite);

    return XST_SUCCESS;
}

/****************************************************************************/
/**
*
* This function setups the interrupt system such that interrupts can occur
* for the UartLite device. This function is application specific since the
* actual system may or may not have an interrupt controller. The UartLite
* could be directly connected to a processor without an interrupt controller.
* The user should modify this function to fit the application.
*
* @param UartLitePtr contains a pointer to the instance of the UartLite
* component which is going to be connected to the interrupt
* controller.
*
* @return XST_SUCCESS if successful, otherwise XST_FAILURE.
*
* @note None.
*
****************************************************************************/
int SetupInterruptSystem(XUartLite *UartLitePtr)
{

	int Status;

/*
* Initialize the interrupt controller driver so that it is ready to
* use.
*/
	Status = XIntc_Initialize(&InterruptController, INTC_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	* Connect a device driver handler that will be called when an interrupt
	* for the device occurs, the device driver handler performs the
	* specific interrupt processing for the device.
	*/
	Status = XIntc_Connect(&InterruptController, UARTLITE_INT_IRQ_ID,
	(XInterruptHandler)XUartLite_InterruptHandler,
	(void *)UartLitePtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	* Start the interrupt controller such that interrupts are enabled for
	* all devices that cause interrupts, specific real mode so that
	* the UartLite can cause interrupts through the interrupt controller.
	*/
		Status = XIntc_Start(&InterruptController, XIN_REAL_MODE);
		if (Status != XST_SUCCESS) {
			return XST_FAILURE;
	}

	/*
	* Enable the interrupt for the UartLite device.
	*/
	XIntc_Enable(&InterruptController, UARTLITE_INT_IRQ_ID);

	/*
	* Initialize the exception table.
	*/
	Xil_ExceptionInit();

	/*
	* Register the interrupt controller handler with the exception table.
	*/
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
	(Xil_ExceptionHandler)XIntc_InterruptHandler,
	&InterruptController);

	/*
	* Enable exceptions.
	*/
	Xil_ExceptionEnable();

	return XST_SUCCESS;
}

void SendHandler(void *CallBackRef, unsigned int EventData)
{
    TotalSentCount = EventData;
}

void RecvHandler(void *CallBackRef, unsigned int EventData)
{
	XUartLite_Recv(&UartLite, ReceiveBufferPtr, 2);
	ReceiveBufferPtr += 2;
	TotalReceivedCount += 2;
}

void uart_sd(u32 sd_addr){

    while (1){
    	//If we've reached the end of the buffer, write to memory

		if (ReceiveBufferPtr >= (&ReceiveBuffer[0] + UART_BUFFER_SIZE)){

			// copy the buffer over
			for(int i=0; i<UART_BUFFER_SIZE; i++){
				BufferCopy[i] = ReceiveBuffer[i];
				// xil_printf("%d\n", BufferCopy[i]);
			}

			// xil_printf("Resetting Receive Buffer\n");
			resetBuffer();

			ReceiveBufferPtr = &ReceiveBuffer[0];
			TotalReceivedCount = 0;

			xil_printf("done one UART buffer cycle\n");

		break;
		}
    }

    // SD card write
	sd_write(sd_addr, UART_BUFFER_SIZE, &BufferCopy[0]);
	xil_printf("done writing to SD card\n");

	// SD card read, just checking
	// can also expand this to a true or false check to see if we get what we wrote

	// int* read_arr[UART_BUFFER_SIZE];
	// sd_read(sd_addr, UART_BUFFER_SIZE, read_arr);
}

void resetBuffer()
{
    for(int i=0;i<UART_BUFFER_SIZE;i++){
    	ReceiveBuffer[i]=0;
    }

    SendBuffer[0] = 0;
    TotalSentCount = 0;
}
