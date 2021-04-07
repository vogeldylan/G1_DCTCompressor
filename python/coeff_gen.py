'''
Generate a hex file for loading the DCT coefficients into vivado
'''

import math as m
from os import write

FILENAME = 'ram_coeff.mem'
BIT_DEPTH = 9

def write_coeffs():
    coeff_arr = [0] * 7
    hex_places = m.ceil(BIT_DEPTH/4) + 2

    print("coefficient values: ")
    for k in range(1, 8): # [1, 7)
        # compute the coefficient value
        coeff_arr[k-1] = 0.5 * m.cos(k*m.pi/16)
        # round to some bit depth
        coeff_arr[k-1] = round(coeff_arr[k-1] * (2**BIT_DEPTH))
        print(coeff_arr[k-1]) 
        # encode as hex
        # coeff_arr[k-1] = hex(coeff_arr[k-1])
        coeff_arr[k-1] = "{0:#0{1}x}".format(coeff_arr[k-1], hex_places)
        # print for sanity
        


    with open(FILENAME, 'wb') as file:
        # even coeffs
        file.write((coeff_arr[4-1] + '\n').encode('ascii'))
        file.write((coeff_arr[4-1] + '\n').encode('ascii'))
        file.write((coeff_arr[4-1] + '\n').encode('ascii'))
        file.write((coeff_arr[4-1] + '\n').encode('ascii'))

        file.write((coeff_arr[2-1] + '\n').encode('ascii'))
        file.write((coeff_arr[6-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[6-1]) + '\n').encode('ascii'))
        file.write((comp(coeff_arr[2-1]) + '\n').encode('ascii'))

        file.write((coeff_arr[4-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[4-1]) + '\n').encode('ascii'))
        file.write((comp(coeff_arr[4-1]) + '\n').encode('ascii'))
        file.write((coeff_arr[4-1] + '\n').encode('ascii'))

        file.write((coeff_arr[6-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[2-1]) + '\n').encode('ascii'))
        file.write((coeff_arr[2-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[6-1]) + '\n').encode('ascii'))

        # odd coeffs
        file.write((coeff_arr[1-1] + '\n').encode('ascii'))
        file.write((coeff_arr[3-1] + '\n').encode('ascii'))
        file.write((coeff_arr[5-1] + '\n').encode('ascii'))
        file.write((coeff_arr[7-1] + '\n').encode('ascii'))

        file.write((coeff_arr[3-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[7-1]) + '\n').encode('ascii'))
        file.write((comp(coeff_arr[1-1]) + '\n').encode('ascii'))
        file.write((comp(coeff_arr[5-1]) + '\n').encode('ascii'))

        file.write((coeff_arr[5-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[1-1]) + '\n').encode('ascii'))
        file.write((coeff_arr[7-1] + '\n').encode('ascii'))
        file.write((coeff_arr[3-1] + '\n').encode('ascii'))

        file.write((coeff_arr[7-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[5-1]) + '\n').encode('ascii'))
        file.write((coeff_arr[3-1] + '\n').encode('ascii'))
        file.write((comp(coeff_arr[1-1]) + '\n').encode('ascii'))


def comp(num_str):
    ''' take the complement '''
    num_int = int(num_str, 16)
    hex_places = m.ceil(BIT_DEPTH/4)

    mask = (2**BIT_DEPTH) - 1

    num_comp = (num_int ^ mask) + 1

    return "{0:#0{1}x}".format(num_comp, hex_places)

if __name__ == "__main__":
    write_coeffs()
    # comp(hex(12))

