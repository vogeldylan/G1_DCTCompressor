import serial
import cv2 as cv
import os
from PIL import Image
import struct
import time
import numpy as np

'''
some references
1. https://maker.pro/pic/tutorial/introduction-to-python-serial-ports
2. Pyserial API documentation https://pythonhosted.org/pyserial/pyserial_api.html#classes

pip install opencv-python PySerial Pillow numpy
'''

# input_dir = "W:\ece532-project"
input_dir = "L:\More-Documents\ROB501\ECE532"
ComPort = "COM6"
UART_BUFFER_SIZE = 64
FULL_TEST = True


def read_img(num):
    # read each image as one band
    if (num < 10):
        img_str = "flowers_ms_0" + str(num) + ".png"
    else:
        img_str = "flowers_ms_" + str(num) + ".png"

    # use openCV to get 8-bit image
    img = cv.imread((os.path.join(input_dir, img_str)), cv.IMREAD_GRAYSCALE)

    '''
    PIL's way to get full image depth, but not needed in this project
    '''
    # img = Image.open((os.path.join(input_dir, img_str)))
    # img_pixels = np.array(img.getdata())
    # img_pixels = img_pixels.reshape(img.height, img.width)

    # cv.imshow("8-bit image", img)
    # cv.waitKey()

    return img


def split_img(img, row_size, col_size):
    # split the image based on row and colume size of the required image
    # img is a numpy array of pixel values
    row_split_num = int(img.shape[0] / row_size)
    col_split_num = int(img.shape[1] / row_size)
    img_list = []

    imgx = np.split(img, row_split_num)

    for i in range(row_split_num):
        imgy = np.split(imgx[i], col_split_num, axis=1)
        for j in range(col_split_num):
            img_list.append(imgy[j])

    img_list = np.array(img_list)

    return img_list

# add 0 to the rest of the array for a valid UART packet
def add_padding(img_list):
    img_block_num_ori = img_list.shape[0]
    img_block_num = int((7 - img_block_num_ori % 7) + img_block_num_ori)

    new_img_list = np.zeros((img_block_num, 8, 8))

    new_img_list[:img_block_num_ori, :, :] = img_list

    return new_img_list

def uart_op(img_list):
    packet_num = int((img_list.shape[0] / 7))

    print("Initializing serial port...")
    print("expected block number {}, expected package number {}".format(img_list.shape[0], packet_num))
    print("each block is a flattened image of size {}".format(len(img_list[0].flatten())))

    ser = serial.Serial(port=ComPort, baudrate=115200, bytesize=8, timeout=0, stopbits=serial.STOPBITS_ONE, rtscts=1)

    while (1):
        # sending one full image for FULL_TEST
        if (FULL_TEST):
            for i in range(packet_num):
                if (i > 0):
                    ser.open()
                    # time.sleep(3)
                    # can't sleep, has time drift

                    # use uart handshake
                    rec = ser.read().decode("ASCII")
                    while (rec != "!"):
                        rec = ser.read().decode("ASCII")

                for k in range(7):
                    img_payload = img_list[i * 7 + k].flatten()

                    for j in range(len(img_payload)):
                        # send one pixel, 8-bit at a time
                        # use B to represent unsigned char
                        sendData = struct.pack('>B', img_payload[j])
                        x = ser.write(sendData)

                ser.close()
                print("Sent block {}".format(i * 7 + k))
            break

        else:
            for i in range(int(UART_BUFFER_SIZE / 2)):
                # send a 2-byte number at a time
                sendData = struct.pack('>H', img_list[i])
                x = ser.write(sendData)
            break

    ser.close()
    print("Done sending image, closed serial port")


if __name__ == '__main__':
    # image input
    img = read_img(31)
    # split image into 8x8 blocks
    img_smol = split_img(img, 256, 256)
    img_list = split_img(img_smol[1], 8, 8)
    # cv.imshow("small img", img_list[9])
    # cv.waitKey()
    img_list_pad = add_padding(img_list)

    # UART operation
    uart_op(img_list_pad)
    cv.imshow("original small img", img_smol[1])
    cv.waitKey()

