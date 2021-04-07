'''
Visualization for compressed image coefficients
Program will obtain coefficient data from TCP and display the decompressed image

Author: Brytni Richards
Last modified: 2021-03-31

Required:
pip install matplotlib
python -m pip install windows-curses
'''

# ============================================================================
# IMPORTS 
# ============================================================================

import curses
import logging
import queue
import socket
import threading
import struct
import copy
import numpy as np
import matplotlib
#matplotlib.use('Qt4Agg') # For Mac
import matplotlib.pyplot as plt
import time
from dct_alg_util import get_decompressed_block

# TCP FPGA mirror server port and ip adress
host = '1.1.5.2'
tcp_port = 7

# For curses writing synchronization
lock = threading.Lock()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Image size requirements
img_size = 256
img = np.zeros((img_size,img_size))

# ============================================================================
# SOCKET AND MESSAGE CLASSES
# ============================================================================

rx_q = queue.Queue(maxsize = 2048)
rx_q_telem = queue.Queue(maxsize = 2048)

class rx_data_msg:
    '''For image data'''
    # args:
    #   int msg_type
    #   int msg_length
    #   tuple data
    # Initialize with relevant values to store into the queue
    def __init__(self, msg_type, msg_length, data):
        self.msg_type = msg_type
        self.msg_length = msg_length
        self.data = copy.deepcopy(data)

class rx_telem_msg:
    '''For telemetry data'''
    # args:
    #   int msg_type
    #   int msg_length
    #   int data
    def __init__(self, msg_type, msg_length, data):
        self.msg_type = msg_type
        self.msg_length = msg_length
        self.data = data
    # Message purpose
    def msg_str(self):
        if self.msg_type == 1:
            return 'Bandwidth Telemetry: '
        if self.msg_type == 2:
            return 'Compression Ratio: '
        return 'Invalid Telemetry Message: ' + str(self.msg_type)


def main_rx(rx_port):
    ''' Main entrypoint for the python RX

    Args:
        rx_port (int):  Port to open on the socket
    '''
    global rx_q

    # socket setup
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((host, rx_port))
        logger.info("Connected to host: "+str(host)+" port: "+str(rx_port)+"\r")

        while True:
            # Required handshaking prompt
            logger.info("Sending request...")
            s.sendall(b"S")
            logger.info('Listening for message ...\r')
            # Receive data from server
            # first 2 bytes are message type
            try:
                type_bytes = s.recv(2)
            except:
                lock.acquire()
                logger.info('TCP socket closed\r')
                lock.release()
                break
            lock.acquire()
            if not type_bytes:
                logger.info('TCP socket closed\r')
                lock.release()
                break
            msg_type = struct.unpack('>BB', type_bytes)
            msg_type = msg_type[1]
            logger.info("Received message type "+str(msg_type)+"\r")
            # collect the entire message
            recv_msg = b''
            if (msg_type == 0) or (msg_type == 1) or (msg_type == 2):
                # second 2 bytes are message length
                [msg_len,] = struct.unpack('>H', s.recv(2))
                logger.info("Received message length "+str(msg_len)+"\r")
                while True:
                    # Each TCP message has a total of 130 bytes, but only msg_len bytes are used
                    recv = s.recv(130 - len(recv_msg))
                    if not recv:
                        logger.info('TCP socket closed earlier than expected\r')
                        break
                    recv_msg += recv
                    if len(recv_msg) == 130:
                        # Store image data as halfwords
                        if (msg_type == 0):
                            num_halfwords = int(len(recv_msg)/2)
                            form_str = '>' + 'H'*num_halfwords
                        # Store telemetry data
                        else:
                            form_str = '>'+'B'*130
                        recv_msg = struct.unpack(form_str, recv_msg)
                        logger.info("Data message: "+str(recv_msg)+"\r")
                        break

                # Add data into queue for processing
                if (msg_type == 0):
                    data_msg = rx_data_msg(msg_type, msg_len, recv_msg[0:int(msg_len/2)])
                    rx_q.put(data_msg, block=True, timeout=5)
                # Add telemetry data into queue
                if (msg_type == 1) or (msg_type == 2):
                    # Concatenate telemetry byte data into one integer
                    int_data = int.from_bytes(recv_msg[0:msg_len], "little")
                    telem_msg = rx_telem_msg(msg_type, msg_len, int_data)
                    rx_q_telem.put(telem_msg, block=True, timeout=5)
                lock.release()

def main_display(stdscr):
    # For color
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    stdscr.bkgd(' ', curses.color_pair(1) | curses.A_BOLD)

    stdscr.clear()

    stdscr.addstr("Showing Telemetry Data\n", curses.color_pair(1))
    stdscr.addstr("-"*80 + "\n\n\r")
    stdscr.refresh()
    while True:
        # Wait for telemetry data
        rx_msg = rx_q_telem.get()
        lock.acquire()
        # Show new telemetry data
        display_msg = str(rx_msg.msg_str()) + str(rx_msg.data) + '\n\r'
        stdscr.addstr(display_msg, curses.color_pair(1))
        stdscr.refresh()
        lock.release()
        curses.napms(100)

def main_display_no_curses():
    print("Showing Telemetry Data\n")
    print("-"*80 + "\n\n\r")
    while True:
        # Wait for telemetry data
        rx_msg = rx_q_telem.get()
        lock.acquire()
        # Show new telemetry data
        display_msg = str(rx_msg.msg_str()) + str(rx_msg.data) + '\n\r'
        print(display_msg)
        lock.release()
        time.sleep(1)

def main():
    global rx_q
    global rx_q_telem
    # Thread to obtain TCP data
    rx_t = threading.Thread(target=main_rx, args=(tcp_port,))
    rx_t.start()

    # Thread to run curses terminal - comment these lines to stop using curses
    disp_t = threading.Thread(target=curses.wrapper, args=(main_display,))
    disp_t.start()

    # Uncomment these lines to use the terminal with no curses library instead
    # disp_t = threading.Thread(target=main_display_no_curses)
    # disp_t.start()

    # Show coefficient visuals - matplotlib doesn't work inside threads
    i = 0
    block_size = 8
    total_rows = int(img_size/block_size)
    while True:
        rx_msg = rx_q.get()
        # process the coefficient into decompressed image data
        decomp_img_data = get_decompressed_block(rx_msg.data)
        # reconstruct image from decompressed data
        y = int((i%total_rows)*block_size)
        x = int(int(i/total_rows)*block_size)
        img[y:(y+block_size), x:(x+block_size)] = decomp_img_data
        i += 1
        if (i == total_rows*total_rows):
            break
    # Show decompressed image
    plt.title("Decompressed image")
    plt.imshow(img)
    plt.show()

if __name__ == "__main__":
    main()
    