# =============================================================================
# DCT image compression algorithm
# Author: Dylan Vogel
# Last modified: 2021-03-29
# =============================================================================

# =============================================================================
# IMPORTS
# =============================================================================

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

# =============================================================================
# GLOBALS
# =============================================================================

# img_path = "C:\\Users\\vogel\\OneDrive\\University\\Winter 4\\ECE532\\Datasets\\complete_ms_data\\pompoms_ms\\pompoms_ms"
# img_name = "pompoms_ms_25.png"
img_path = "C:\\Users\\vogel\\OneDrive\\University\\Winter 4\\ECE532\\Datasets\\complete_ms_data\\flowers_ms\\flowers_ms"
img_name = "flowers_ms_31.png"

coeff_name = "coeffs_sim.log"
# coeff_name = "coeff11.log"

# img_path = "C:\\Users\\vogel\\OneDrive\\University\\Winter 4\\ECE532\\Datasets\\complete_ms_data\\fake_and_real_lemon_slices_ms\\fake_and_real_lemon_slices_ms"
# img_name = "fake_and_real_lemon_slices_ms_31.png"

DCT_BLOCK_SIZE = 8
DCT_QUALITY = 50
IMG_BIT_DEPTH = 8
COEFF_BIT_DEPTH = 9

logger = logging.getLogger(__name__)

def get_image(image_file):
    ''' Open the specified image file and return a 2D array of the pixel intensities
    Args:
        image_file (str): image filename, including path
    Returns:
        numpy.array: 2D array of image values
    '''
    
    im = pil.Image.open(image_file)
    # TODO: add handling of RGB images

    imarr = np.array(im)
    imarr = imarr >> 8

    return imarr


def get_next_dct_block(image):
    (x, y) = image.shape

    for i in range(int(x/8)):
        for j in range(int(y/8)):
            yield image[(i*8):(i+1)*8, (j*8):(j+1)*8]


def round_base(num, base):
    return base * round(num/base)

'''
Return the decoded set of coefficients reperesented by a single run length value

Args:
    val (int): integer, should be 16 bits wide
Returns:
    list: equivalent coefficients

'''
def get_run_length_decode(val):
    ZERO_FLAG = 1 << 15 # bit 15 indicates 0 or nonzero
    ZERO_CNT_MASK = 0x7E00 # bits 14-9 are the zero cnt
    ZERO_CNT_OFFSET = 9 # bit 9 is the start of the zero count

    NEG_MASK = 0x2000 # bit 13 should indicate negative number in our representation
    NEG_EXTEND = 0xC000 # for or-ing with the 14-bit negative number
    # probably need to use struct.pack, plus struct.unpack

    decode_arr = []

    if (val & ZERO_FLAG):
        # we have a zero
        zero_count = (val & ZERO_CNT_MASK) >> ZERO_CNT_OFFSET
        # print(f"Zero count?: {zero_count}")

        if (zero_count == 0):
            decode_val = [0 for _ in range(64)]
        else:
            decode_val = [0 for _ in range(zero_count)]

        decode_arr.extend(decode_val)

    else:
        if (val & NEG_MASK):
            # extend the negative number
            decode_val = val | NEG_EXTEND # put a one at bit 15
        else:
            decode_val = val

        # decode the value
        decode_val = struct.pack('>H', decode_val)
        # print(f"Negative bytes?: {decode_val}")
        decode_val = struct.unpack('>h', decode_val)[0] # return the proper signed number
        # print(f"Signed number?: {decode_val}")

        decode_arr.append(decode_val)
    
    return decode_arr
    

'''
Return a decompressed image block from a set of run length coefficients

Args:
    coeff_arr (numpy tuple): tuple of integers representing the run-length coefficients
Returns:
    np.array: 8x8 numpy array of the decompressed image coefficients

'''
def get_decompressed_block(coeff_arr):

    decode_arr = []

    for i in range(len(coeff_arr)):
        coeff = coeff_arr[i]

        # print(f"this is coeff: {coeff}")

        if (coeff == 0xFFFF):
            # end of this block
            break

        # decode the current coefficient
        decode_coeff = get_run_length_decode(coeff)
        # extend our black tracking the values
        decode_arr.extend(decode_coeff)

    if (len(decode_arr) > 64):
        # too big
        decode_arr = decode_arr[0:64]
        # raise ValueError(f"Expected decoded array length of 64, got {len(decode_arr)}")
    elif (len(decode_arr) < 64):
        # too small
        decode_arr = decode_arr.extend([0 for _ in range(64-len(decode_arr))])

    # get myself an instance of the class for decompression
    dct = dct_compressor(DCT_BLOCK_SIZE, DCT_QUALITY, pow2=True)

    decode_arr = dct.get_un_zigzag(decode_arr)

    decode_block = np.array(decode_arr).reshape((8,8)) * 0.5 # the 1/2 corrects for fixed width math
    # print(f"Decode block?: \n{decode_block}")

    decode_block = dct.get_unquantized(decode_block)
    decode_block = dct.get_image_from_weights(decode_block)

    return decode_block


class dct_compressor:
    # subjective quantization matrix, for bit depth 255
    QUANTIZATION_MATRIX = np.array(\
        [[  16, 11, 10, 16, 24, 40, 51, 61  ],\
         [  12, 12, 14, 19, 26, 58, 60, 55  ],\
         [  14, 13, 16, 24, 40, 57, 69, 56  ],\
         [  14, 17, 22, 29, 51, 87, 80, 62  ],\
         [  18, 22, 37, 56, 68, 109,103,77  ],\
         [  24, 36, 55, 64, 81, 104,113,92  ],\
         [  49, 64, 78, 87, 103,121,120,101 ],\
         [  72, 92, 95, 98, 112,100,103,99  ]])


    def __init__(self, dct_block_size, dct_quality, pow2=True):
        self._dct_block_size = dct_block_size
        self.set_matrix() # build the transform matrix
        self.set_quantization_matrix(dct_quality, pow2=pow2) # build the quantization matrix
        self.addr_width = 6

    def set_matrix(self):
        # transform matrix
        self.T = np.fromfunction(self.matrix_fn, (self._dct_block_size, self._dct_block_size))
        self.T_transpose = np.transpose(self.T)

    def matrix_fn(self, x, y):
        ''' function to compute each element of the DCT matrix
        '''
        # build the array
        matrix = m.sqrt(2/self._dct_block_size) * np.cos((2*y + 1)*x * m.pi / (2*self._dct_block_size))
        # fix the first row values
        matrix[0, :] = 1/np.sqrt(self._dct_block_size)
        return matrix

    def set_quantization_matrix(self, dct_quality, pow2=False):
        # check for funny business
        if (dct_quality <= 0) or (dct_quality > 100):
            raise ValueError("Compression quality must be between (0, 100]")

        # return quantization matrix to a power of 2
        if (pow2):
            quantization_matrix = np.power(2, np.round(np.log2(self.QUANTIZATION_MATRIX)))
            # adjust quantization to user-specified quality
        else:
            if (dct_quality >= 50):
                quantization_matrix = self.QUANTIZATION_MATRIX * (dct_quality/50)
            else:
                quantization_matrix = self.QUANTIZATION_MATRIX * (50/dct_quality)

            # to convert from 8-bit to image bit depth
            scaling_factor = (2**IMG_BIT_DEPTH - 1)/(2**8 - 1)

            # round and clip values
            quantization_matrix = np.round(quantization_matrix * scaling_factor)
            quantization_matrix = np.clip(quantization_matrix, 0, 2**IMG_BIT_DEPTH - 1)

        # print(f"Quantization matrix: \n{quantization_matrix}")
        self._q_matrix = quantization_matrix

        return


    def get_weights(self, block):
        #print(block)
        block = block - (2**(IMG_BIT_DEPTH - 1))
        #print(block)
        # TODO: check if this is in-place, I think so
        block = np.matmul(block, self.T_transpose) # M * T'
        block = np.matmul(self.T, block) # T * M * T'

        return block

    def get_quantized(self, block):
        # TODO: check if this is in-place
        return np.round(np.divide(block, self._q_matrix))


    def get_entropy_code(self, block):
        logger.warning("Entropy coding isn't implemented yet")
        return block

    def get_unquantized(self, block):
        return block * self._q_matrix

    def get_image_from_weights(self, block):
        block = np.matmul(block, self.T)
        block = np.round(np.matmul(self.T_transpose, block))
        block = block + (2**(IMG_BIT_DEPTH - 1))

        return block

    def get_addsub(self, row, input_shift=False):
        addsub = np.zeros((8,1))
        for i in range(4):
            addsub[i] = row[i] + row[7-i]
            if input_shift:
                addsub[i] = addsub[i] - 256
            addsub[i+4] = row[i] - row[7-i] 
        
        # print(addsub)

        return addsub

    def get_fgpa_coeffs(self):
        coeff_mat = np.zeros((1, 8*4))

        coeff_arr = [0] * 7
        for k in range(1, 8): # [1, 7)
            # compute the coefficient value
            coeff_arr[k-1] = 0.5 * m.cos(k*m.pi/16)
            # round to some bit depth
            coeff_arr[k-1] = round(coeff_arr[k-1] * (2**COEFF_BIT_DEPTH))

        coeff_mat[0, 0] = (coeff_arr[4-1])
        coeff_mat[0, 1] = (coeff_arr[4-1])
        coeff_mat[0, 2] = (coeff_arr[4-1])
        coeff_mat[0, 3] = (coeff_arr[4-1])

        coeff_mat[0, 4] = (coeff_arr[2-1])
        coeff_mat[0, 5] = (coeff_arr[6-1])
        coeff_mat[0, 6] = (- coeff_arr[6-1])
        coeff_mat[0, 7] = (- coeff_arr[2-1])

        coeff_mat[0, 8] = (coeff_arr[4-1])
        coeff_mat[0, 9] = (-coeff_arr[4-1])
        coeff_mat[0, 10] = (-coeff_arr[4-1])
        coeff_mat[0, 11] = (coeff_arr[4-1])

        coeff_mat[0, 12] = (coeff_arr[6-1]) 
        coeff_mat[0, 13] = (-coeff_arr[2-1])
        coeff_mat[0, 14] = (coeff_arr[2-1]) 
        coeff_mat[0, 15] = (-coeff_arr[6-1])

        # odd coeffs
        coeff_mat[0, 16] = (coeff_arr[1-1])
        coeff_mat[0, 17] = (coeff_arr[3-1])
        coeff_mat[0, 18] = (coeff_arr[5-1])
        coeff_mat[0, 19] = (coeff_arr[7-1])

        coeff_mat[0, 20] = (coeff_arr[3-1]) 
        coeff_mat[0, 21] = (-coeff_arr[7-1])
        coeff_mat[0, 22] = (-coeff_arr[1-1])
        coeff_mat[0, 23] = (-coeff_arr[5-1])

        coeff_mat[0, 24] = (coeff_arr[5-1])
        coeff_mat[0, 25] = (-coeff_arr[1-1])
        coeff_mat[0, 26] = (coeff_arr[7-1])
        coeff_mat[0, 27] = (coeff_arr[3-1])

        coeff_mat[0, 28] = (coeff_arr[7-1])
        coeff_mat[0, 29] = (-coeff_arr[5-1])
        coeff_mat[0, 30] = (coeff_arr[3-1])
        coeff_mat[0, 31] = (-coeff_arr[1-1])

        coeff_mat = coeff_mat.reshape((8,4))

        # print(coeff_mat)

        return coeff_mat

    def get_1d_dct(self, addsub, coeff_mat):
        result = np.zeros((1,8))
        multacc_even = coeff_mat[0:4, :] @ addsub[0:4, :]
        multacc_odd = coeff_mat[4:8, :] @ addsub[4:8, :]

        # print(f"even: {multacc_even}")
        # print(f"odd: {multacc_odd}")

        result[0, 0] = multacc_even[0]
        result[0, 1] = multacc_odd[0]
        result[0, 2] = multacc_even[1]
        result[0, 3] = multacc_odd[1]
        result[0, 4] = multacc_even[2]
        result[0, 5] = multacc_odd[2]
        result[0, 6] = multacc_even[3]
        result[0, 7] = multacc_odd[3]

        # print(f"result: {result}")

        return result

    def index_from_row_col(self, row, col):
        return row*8 + col 
    
    def get_un_zigzag(self, arr):
        total_addr = 2**self.addr_width
        max_addr = m.sqrt(total_addr) - 1 # assuming square matrix

        out_arr = [0 for _ in range(total_addr)]

        # track the current input array index
        input_ind = 0

        # initialize the row and column indicies
        curr_row = 0
        curr_col = 0

        # initalize the change in each index
        d_row = 0
        d_col = 1

        while (curr_row < max_addr + 1) and (curr_col < max_addr + 1):
            # get the current index
            ind = self.index_from_row_col(curr_row, curr_col)

            # output the input coefficient at the correct zig-zag index
            out_arr[ind] = arr[input_ind]

            if (curr_row == max_addr and curr_col == max_addr):
                # we're done
                break

            # print(f"Curr row: {curr_row}, Curr col: {curr_col}")
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
                
            input_ind += 1

        return out_arr
        
if __name__ == "__main__":

    image = get_image(img_path + '\\' + img_name)
    # get the upper-right corner
    image = image[0:256, 256:]

    (x,y) = image.shape

    i = 0
    j = 0

    n_coeff = 0

    out_img = np.zeros((x,y))

    curr_arr = []

    with open(coeff_name, 'r+') as file:
        for line in file:
            val = int(line)
            n_coeff += 1

            # print(f"{val}")

            curr_arr.append(val)

            # check for EOF
            if val == 0xFFFF:
                block = get_decompressed_block(curr_arr)
                # print(f"got block: {block}")
                out_img[(i*8):(i+1)*8, (j*8):(j+1)*8] = block

                # print(f"i: {i}, j:{j}")
                if(j==31 and i==31):
                    # end of image
                    break

                if (j==31):
                    # end of column
                    i += 1
                
                j = (j+1)%32

                # print("End of packet")
                next_line = next(file)
                next_val = int(next_line)

                n_coeff += 1
                if next_val != 0xFFFF:
                    # new data
                    # print("Starting next packet with val")
                    curr_arr = [next_val]
                else:
                    # part of the last packet
                    curr_arr = []
                    # print("starting next packet without val")

    out_img = np.clip(out_img, 0, 255)

    fig = plt.figure(figsize=(14, 4))

    fig.add_subplot(1, 3, 1)

    plt.imshow(image, cmap="gray")
    plt.title("Original")

    plt.subplot(1, 3, 2)

    plt.imshow(out_img, cmap="gray")
    compression_ratio = 65535 / (n_coeff * 2)
    plt.title(f"Decompressed Image\n Compression Ratio: {compression_ratio:.2f}")

    image_error = image - out_img

    fig.add_subplot(1, 3, 3)

    plt.imshow(image_error, cmap="gray")
    plt.title("Image Error")

    plt.show()


    # test array from the pompom image
    # runlen_arr = [0x3fe9, 0x0006, 0x3ffb, 0xfa00, 0xffff, 0xffff]

    # runlen_arr = (33087, 254, 65535, 65535)

    # # zig_zag_arr = [i for i in range(64)]
    # # dct = dct_compressor(DCT_BLOCK_SIZE, DCT_QUALITY, pow2=True)

    # # un_zig_zag = dct.get_un_zigzag(zig_zag_arr)
    # # un_zig_zag = np.array(un_zig_zag).reshape((8,8))
    # # print(f"Un zig-zag?: \n{un_zig_zag}")

    # decode_block = get_decompressed_block(runlen_arr)

    # print(f"Got back:\n{decode_block}")

    # plt.imshow(decode_block)

    # plt.show()

