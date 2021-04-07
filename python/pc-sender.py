# Testing on python side for tcp

import socket
import _thread
import struct
import time

HOST = '1.1.8.2' # The IP address of the computer this script runs on (or change to 127.0.0.1 for localhost)
PORT = 7 # The port used by this TCP server 

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    print("going to connect to host...")
    s.connect((HOST, PORT))
    print("connected to host")

    # Loop until connection closed
    packet = 1
    
    '''
    for i in range (4):
        # For telemetry data testing
        if packet == 1:
            msg = [b"R", 1, 4, i+1000]
            form_str = '>chhI'
            data = struct.pack(form_str, *msg) 
            # Send data back to sender (echo)
            s.send(data)
            print("Sent", repr(data))
    '''
    packet = 0
    for i in range (8):
        # For image data testing
        if packet == 0:
            # Since sending halfwords, data length is #bytes * 2
            msg = [b"R", 0, 6, 1,2,i]
            form_str = '>'+'cB'+'h'*(len(msg)-2)
            data = struct.pack(form_str, *msg) # returns a byte object

        # Send data back to sender (echo)
        if i==0:
            s.send(data)
            print("Sent", repr(data))
            continue
        
        recv_data = " "
        while(recv_data != b"RDY"):
            recv_data = s.recv(3)
        
        s.send(data)
        print("Sent", repr(data))

    # Close the connection if break from loop
    s.shutdown(1)
    s.close()
    print("Connectiont closed")
