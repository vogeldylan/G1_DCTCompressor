# Example of simple tcp client (expects echo server)

import socket
import struct

HOST = "1.1.11.2"  # The remote server's hostname or IP address
PORT = 7  # The port used by the remote server
pack_num = 2 # test packet number
count = 0
send_act = False
recv_act = True

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))
    print("connected to host")
    
    if(recv_act):
        s.sendall(b"R00512345")
        count = count + 1
        
        s.sendall(b"R00585415")
        count = count + 1
        
        '''
        while(count < pack_num):
            data = " "
            while(data != b"403ACK"):
                data = s.recv(6)
                print("Received", repr(data))
               
            if(count < pack_num):
               s.sendall(b"R04TEST")
               count = count + 1
        '''
    
    if(send_act):
        s.sendall(b"S")
        
        while(1):
            pass
            
    s.shutdown(1)
    s.close()