'''
A simple demo file demonstrating terminal visualization using curses

Author: Dylan Vogel
Last Modified: 2021-02-23
'''

# ============================================================================
# IMPORTS 
# ============================================================================

import attr
import ast
import curses
import logging
import queue
import socket
import threading

import struct

logger = logging.getLogger(__name__)

# ============================================================================
# SOCKET AND MESSAGE CLASSES
# ============================================================================

rx_q = queue.Queue(maxsize = 100)

@attr.s
class rx_telem_msg:
    ''' Class for message objects passed between the receiver and transmitter
    
        Args:
            hw_id (int):        id of the fpga
            msg_type (int):     type of message
            msg (list or str):  string, list or list-like string
    '''

    # pylint: disable=no-self-argument
    def _conv_str_to_list(value):
        ''' used to convert strings or list-looking strings to lists
        '''
        if isinstance(value, str):
            if value[0] == '[':
                # looks like a list, will it evaluate to a list?
                try:
                    return ast.literal_eval(value)
                except ValueError:
                    # no it will not
                    logger.warning("Passed value looked like a list but couldn't eval; parsing as string")
            else:
                # turn the string into a list of chars
                return [ord(c) for c in value]      # encode to list of chars
        elif isinstance(value, list):
            # already a list!
            return value
        raise ValueError("Value passed is not list of ints or string")

    hw_id = attr.ib(converter=int)
    msg_type = attr.ib(converter=int)
    msg = attr.ib(converter=_conv_str_to_list)

    def __str__(self):
        ''' Represent ourselves as a string, convenient for transmitting'''
        return '{}::{}::{}'.format(self.hw_id, self.msg_type, self.msg)

    @classmethod
    def parse(cls, value):
        ''' Attempt to create a msg object from our self-defined string representation '''
        vals = value.split('::')
        return cls(*vals)

def main_rx(rx_port):
    ''' Main entrypoint for the python RX

    Args:
        rx_port (int):  Port to open on the socket
    '''
    global rx_q

    print("Hello")

    host = ''

    # socket setup
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, rx_port))
        s.listen(1)
        while True:
            logger.info('Listening for connections ...')
            # wait for someone to connect
            conn, addr = s.accept()
            with conn:
                recv_msg = b''
                logger.info('Connected by: {}'.format(addr))
                # first byte is length
                msg_len = int(conn.recv(1))
                # collect the entire message
                while True:
                    recv = conn.recv(msg_len - len(recv_msg))
                    if not recv:
                        logger.error('Socket closed earlier than expected')
                        break
                    recv_msg += recv
                    if len(recv_msg) == msg_len:
                        break
            
                # do something useful with the message
                logger.debug('Received: {}'.format(recv_msg))
                telem_msg = rx_telem_msg.parse(recv_msg.decode('utf-8'))


def main_display(stdscr):
    stdscr.clear()
    # stdscr.nodelay(1)

    while True:
        stdscr.addstr("Testing Terminal Display\n")
        stdscr.addstr("-"*80 + "\n\n")
        rx_msg = rx_q.get()
        stdscr.addstr(f"HW ID:              {rx_msg.hw_id}\n")
        stdscr.addstr(f"Message Type:       {rx_msg.msg_type}\n")
        stdscr.addstr(f"Message Contents:   {rx_msg.msg}\n")
        stdscr.refresh()

        if stdscr.getch() != -1:
            break

        curses.napms(100)



def main():
    global rx_q
    # rx_t = threading.Thread(target=main_rx, args=(3333,))
    # disp_t = threading.Thread(target=curses.wrapper, args=(main_display,))
    
    # rx_t.start()
    # disp_t.start()

    test_msg = rx_telem_msg(hw_id=1, msg_type=3, msg=[1, 2, 3, 4, 5])
    rx_q.put(test_msg)

    curses.wrapper(main_display)


if __name__ == "__main__":
    main()
    





