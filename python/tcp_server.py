# Testing on python side for tcp

import socket
import _thread
import struct
import time

HOST = '127.0.0.1' # The IP address of the computer this script runs on (or change to 127.0.0.1 for localhost)
PORT = 8800 # The port used by this TCP server 

def open_new_client(connection, addr):
    print("Connected to client ", addr[0], " port ", addr[1])

    # Loop until connection closed
    packet = 1

    for i in range (4):
        # For telemetry data testing
        if packet == 1:
            msg = [1, 4, i+1000]
            form_str = '>hhI'
            data = struct.pack(form_str, *msg) 
            # Send data back to sender (echo)
            connection.send(data)
            print("Sent", repr(data))
    packet = 0
    for i in range (4):
        # For image data testing
        if packet == 0:
            # Since sending halfwords, data length is #bytes * 2
            msg = [0, 6, 1,2,3]
            form_str = '>' + 'h'*len(msg)
            data = struct.pack(form_str, *msg) # returns a byte object

        # Send data back to sender (echo)
        connection.send(data)
        print("Sent", repr(data))

    # Close the connection if break from loop
    connection.shutdown(1)
    connection.close()
    print("Connection to client ", addr[0], " port ", addr[1], " closed")

def listen():
    # Setup the socket
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    # Bind to an address and port to listen on
    connection.bind((HOST, PORT))
    connection.listen(10)
    print("Server opened on ",HOST," port ", PORT)

    # Loop forever, accepting all connections in new thread
    while True:
        new_conn, new_addr = connection.accept()
        _thread.start_new_thread(open_new_client,(new_conn, new_addr))

if __name__ == "__main__":
    try:
        listen()
    except KeyboardInterrupt:
        pass