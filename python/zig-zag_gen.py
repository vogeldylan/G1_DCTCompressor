'''
A script to generate a memory file containing the zig-zag encoding 
lookup table indicies

'''

import math as m
import numpy as np

FILENAME = 'zigzag_lookup.mem'
ADDR_WIDTH = 6 

def write_zigzag():

    total_addr = 2**ADDR_WIDTH
    hex_places = m.ceil(ADDR_WIDTH/4) + 2

    max_addr = m.sqrt(total_addr) - 1 # assuming square matrix

    # initialize the row and column indicies
    curr_row = 0
    curr_col = 0

    # initalize the change in each index
    d_row = 0
    d_col = 1


    with open(FILENAME, 'wb') as file:
        while (curr_row < max_addr + 1) and (curr_col < max_addr + 1):
            ind = index_from_row_col(curr_row, curr_col)
            ind = "{0:#0{1}x}".format(ind, hex_places)
            file.write((ind + '\n').encode('ascii'))

            if (curr_row == max_addr and curr_col == max_addr):
                # we're done
                break

            print(f"Curr row: {curr_row}, Curr col: {curr_col}")
            curr_row += d_row
            curr_col += d_col

            if (curr_row == 0 and d_row == -1) or (curr_row == max_addr and d_row == 1):
                # we just approached the top of the matrix
                d_row = 0
                d_col = 1
            elif (curr_row == 0 and d_row == 0) or (curr_col == max_addr and d_col == 0):
                d_row = 1
                d_col = -1
            elif (curr_col == 0 and d_col == -1) or (curr_col == max_addr and d_col == 1):
                d_row = 1
                d_col = 0
            elif (curr_col == 0 and d_col == 0) or (curr_row == max_addr and d_row == 0):
                d_row = -1
                d_col = 1
            else:
                # keep the last derivatives
                pass


def index_from_row_col(row, col):
    return row*8 + col

if __name__ == "__main__":
    write_zigzag()