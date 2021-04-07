'''
A script to generate a memory file containing a test image block

This is used for testing the DCT function itself
'''

#
import logging
import math as m
import struct

# external packages
import matplotlib.pyplot as plt
import matplotlib.colors as clrs
import numpy as np
import PIL as pil
from numpy.core.fromnumeric import compress
import cv2 

from os import write
from dct_alg_util import get_image, get_next_dct_block

img_path = "C:\\Users\\vogel\\OneDrive\\University\\Winter 4\\ECE532\\Datasets\\complete_ms_data\\flowers_ms\\flowers_ms"
img_name = "flowers_ms_31.png"

FILENAME = 'D:\\xilinx-projects\\ECE532\\HealthVivado\\custom_dct\\custom_dct.srcs\\sources_1\\data_files\\dct_test_block.mem'
BIT_DEPTH = 8

def write_test_block():
    test_block = \
    [104, 103, 102, 97, 95, 94, 95, 94,
    107, 105, 103, 99, 97, 97, 96, 95,
    111, 109, 108, 105, 104, 103, 100, 97,
    113, 109, 108, 106, 106, 103, 103, 99,
    109, 109, 108, 107, 106, 109, 106, 104,
    115, 112, 111, 109, 107, 110, 109, 105,
    114, 114, 112, 109, 109, 111, 111, 105,
    117, 117, 116, 113, 112, 110, 106, 104]

    hex_places = m.ceil(BIT_DEPTH/4) + 2

    with open(FILENAME, 'wb') as file:
        # need to write out each array element as ascii-encoded hex
        for i in range(len(test_block)):
            # format the current value
            val = "{0:#0{1}x}".format(test_block[i], hex_places)
            file.write((val + '\n').encode('ascii'))


def write_image_block():
    image = get_image(img_path + '\\' + img_name)
    # get the upper-right corner
    image = image[0:256, 256:]

    (x,y) = image.shape

    # dct_block_gen = get_next_dct_block(image)

    # hex_places = m.ceil(BIT_DEPTH/4) + 2

    # test_arr = []

    # with open(FILENAME, 'wb') as file:
    #     for block in dct_block_gen:
    #         for i in range(8):
    #             for j in range(8):
    #                 val = "{0:#0{1}x}".format(block[i, j], hex_places)
    #                 file.write((val + '\n').encode('ascii'))

    
    # print(image.shape)

    # plt.imshow(image)
    # plt.show()

if __name__ == '__main__':
    # write_test_block()
    write_image_block()