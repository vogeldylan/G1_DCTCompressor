'''
A script to generate a memory file containing the quantizer bit shifts

This scrit assumes that we take the default JTAG quantization matrix
and only implement division as the nearest bit shift operation (in
log scale)

'''

import math as m
import numpy as np

FILENAME = 'D:\\xilinx-projects\\ECE532\\HealthVivado\\custom_dct\\custom_dct.srcs\\sources_1\\data_files\\quant_coeff.mem'
BIT_DEPTH = 8 # this doesn't really matter, just be sure to set your quantization array to this in verilog

def write_quants():
    hex_places = m.ceil(BIT_DEPTH/4) + 2
    QUANTIZATION_MATRIX = np.array(\
            [[  16, 11, 10, 16, 24, 40, 51, 61  ],\
            [  12, 12, 14, 19, 26, 58, 60, 55  ],\
            [  14, 13, 16, 24, 40, 57, 69, 56  ],\
            [  14, 17, 22, 29, 51, 87, 80, 62  ],\
            [  18, 22, 37, 56, 68, 109,103,77  ],\
            [  24, 36, 55, 64, 81, 104,113,92  ],\
            [  49, 64, 78, 87, 103,121,120,101 ],\
            [  72, 92, 95, 98, 112,100,103,99  ]])

    with open(FILENAME, 'wb') as file:
        # need to write out the transpose of the quantization matrix
        # to account for the coefficents being transpose
        quant_mat = np.transpose(QUANTIZATION_MATRIX)
        # iterate over the total # of quantization matrix entries
        for i in range(64):

            quant_val = round(m.log2(quant_mat[i//8, i%8]))
            quant_val = "{0:#0{1}x}".format(quant_val, hex_places)
            file.write((quant_val + '\n').encode('ascii'))


if __name__ == "__main__":
    write_quants()