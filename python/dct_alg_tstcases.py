# =============================================================================
# DCT image compression algorithm test cases, because the other file was
#   getting too unwieldy.
# Author: Dylan Vogel
# Last modified: 2021-03-29
# =============================================================================

from dct_alg_util import *

# =============================================================================
# TEST CASES
# =============================================================================

def do_full_image():
    image = get_image(img_path + "\\" + img_name)

    (x, y) = image.shape

    if (x % 8 != 0):
        logger.warning("Image x dimension is not a multiple of 8, will be truncated")
    if (y % 8 != 0):
        logger.warning("Image y dimension is not a multiple of 8, will be truncated")

    # pre-allocate the compressed array
    image_compressed = np.zeros((round_base(x, 8), round_base(y, 8)))
    image_decompressed = np.zeros((round_base(x, 8), round_base(y, 8)))

    # init the DCT class
    dct = dct_compressor(DCT_BLOCK_SIZE, DCT_QUALITY)

    # get the dct block generator (like in an FPGA implementation?)
    dct_block_gen = get_next_dct_block(image)

    for i in range(int(x/8)):
        for j in range(int(y/8)):
            try:
                block = next(dct_block_gen)
            except RuntimeError:
                logger.error("Somehow ran out of blocks early at (i,j)=({},{})??".format(i,j))
                break
            block = dct.get_weights(block) 
            block = dct.get_quantized(block)
            #block = dct_c.get_entropy_code(block)
            image_compressed[(i*8):(i+1)*8, (j*8):(j+1)*8] = block

            block = dct.get_unquantized(block)
            block = dct.get_image_from_weights(block)
            image_decompressed[(i*8):(i+1)*8, (j*8):(j+1)*8] = block

    image_error = image - image_decompressed
    
    n_nonzeros = np.count_nonzero(image_compressed)

    compression_ratio = round((x*y)/n_nonzeros, 1)

    return (image, image_compressed, image_decompressed, image_error, compression_ratio)

def do_block():
    image = get_image(img_path + "\\" + img_name)
    # image = image[0:8, 0:8]  # only want the first block

    (x, y) = image.shape

    if (x % 8 != 0):
        logger.warning("Image x dimension is not a multiple of 8, will be truncated")
    if (y % 8 != 0):
        logger.warning("Image y dimension is not a multiple of 8, will be truncated")

    # pre-allocate the compressed array
    image_compressed = np.zeros((8, 8))
    image_decompressed = np.zeros((8, 8))

    # init the DCT class
    dct = dct_compressor(DCT_BLOCK_SIZE, DCT_QUALITY)

    # get the dct block generator (like in an FPGA implementation?)
    dct_block_gen = get_next_dct_block(image)

    i = 0;
    j = 0;

    for _ in range(100):
        # get more interesting block?
        block = next(dct_block_gen)

    image = block

    block = dct.get_weights(block) 
    block = dct.get_quantized(block)

    image_compressed[(i*8):(i+1)*8, (j*8):(j+1)*8] = block

    block = dct.get_unquantized(block)
    block = dct.get_image_from_weights(block)
    image_decompressed[(i*8):(i+1)*8, (j*8):(j+1)*8] = block

    image_error = image - image_decompressed
    
    n_nonzeros = np.count_nonzero(image_compressed)

    compression_ratio = round((x*y)/n_nonzeros, 1)

    print("Block only results:")
    print(f"Image: \n{image}")
    print(f"Weights: \n{image_compressed}")
    print(f"Image Decomp.: \n{image_decompressed}")
    print(f"Image Error: \n{image_error}")

    return image, image_compressed, image_decompressed, image_error, compression_ratio


def do_block_fpga():
    image = get_image(img_path + "\\" + img_name)
    # image = image[0:128, 0:128]
    # image = image[0:8, 0:8]  # only want the first block

    (x, y) = image.shape

    if (x % 8 != 0):
        logger.warning("Image x dimension is not a multiple of 8, will be truncated")
    if (y % 8 != 0):
        logger.warning("Image y dimension is not a multiple of 8, will be truncated")

    # pre-allocate the compressed array
    image_compressed = np.zeros((8, 8))
    image_decompressed = np.zeros((8, 8))

    # init the DCT class
    dct = dct_compressor(DCT_BLOCK_SIZE, DCT_QUALITY)

    max_val = 0
    # get the dct block generator (like in an FPGA implementation?)
    dct_block_gen = get_next_dct_block(image)

    while True:

        i = 0;
        j = 0;

        try:
            block = next(dct_block_gen)
        except StopIteration:
            break

        image = block
        # print(f"Image: \n{image}")

        # get the 1D coefficient matrix
        coeff_mat = dct.get_fgpa_coeffs()

        # perform the row DCT
        row_dct = np.zeros((8,8))

        for i in range(8):
            # print(f"On row iteration {i}")
            row = block[i, :]
            # print(row)
            addsub = dct.get_addsub(row, input_shift=True)
            row_dct[i, :] = dct.get_1d_dct(addsub, coeff_mat)
        
        # bit shift by >> 9
        # print(f"Row dct pre bit shift: \n{row_dct}")
        row_dct = (row_dct / (2**0)).astype(int)
        # print(f"Row dct post bit shift: \n{row_dct}")

        # print("Done row DCT")

        # update the block we're working with
        block = row_dct.transpose()
        # print(f"Transposed row DCT: {block}")

        # perform the column DCT
        col_dct = np.zeros((8,8))
        for i in range(8):
            # print(f"On column iteration {i}")
            row = block[i, :]
            # print(row)
            addsub = dct.get_addsub(row, input_shift=False)
            col_dct[i, :] = dct.get_1d_dct(addsub, coeff_mat)

        # bit shift by >> 12
        col_dct = (col_dct / (2**0)).astype(int)

        # print("Done column DCT")
        # print(f"Un-quantized DCT: \n{col_dct}")

        block = dct.get_quantized(col_dct.transpose())

        max_block = np.max(np.abs(block))
        if max_block > max_val:
            max_val = max_block

        block = (block / (2**21)).astype(int)

        if (np.any(block != 0)):
            pass
            # print("we got a nonzero block")
            # break

    image_compressed = block

    # do the reverse using python
    block = dct.get_unquantized(block)
    block = dct.get_image_from_weights(block)
    image_decompressed = block

    image_error = image - image_decompressed
    
    n_nonzeros = np.count_nonzero(image_compressed)

    # compression_ratio = round((x*y)/n_nonzeros, 1)
    compression_ratio = 1

    print(f"The maximum (pre-quantized) value we got was: {max_val}")
    print(f"This is equvalent to {m.ceil(m.log2(max_val))} bits")

    print("Block only results:")
    print(f"Image: \n{image}")
    print(f"Weights: \n{image_compressed}")
    print(f"Image Decomp.: \n{image_decompressed}")
    print(f"Image Error: \n{image_error}")

    return image, image_compressed, image_decompressed, image_error, compression_ratio

def main(testcase):
    if testcase == 'full':
        main_fn = do_full_image
    elif testcase == 'block':
        main_fn = do_block
    elif testcase == 'block_fpga':
        main_fn = do_block_fpga
    else:
        raise IndexError("Please pass in a valid testcase you goose")

    image, image_compressed, image_decompressed, image_error, compression_ratio = main_fn()

    # plt.figure(1)
    # plt.imshow(image, cmap="gray")
    # plt.title("Original")
    # plt.figure(2)
    # plt.imshow(image_compressed, cmap="gray")
    # plt.title("DCT Weights")
    # plt.figure(3)
    # plt.imshow(image_decompressed, cmap="gray")
    # plt.title("Reconstructed")
    # plt.figure(4)
    # plt.imshow(image_error, cmap="gray")
    # plt.title("Error")

    fig = plt.figure(figsize=(8,8))

    fig.add_subplot(221)
    fig.suptitle("Python DCT Compression, Quality={}\nCompression Ratio={}".format(DCT_QUALITY, compression_ratio))

    plt.imshow(image, cmap="gray")
    plt.title("Original")

    plt.subplot(2,2,2)
    plt.imshow(image_compressed, cmap="gray")
    plt.title("DCT Weights")

    plt.subplot(2,2,3)
    plt.imshow(image_decompressed, cmap="gray")
    plt.title("Reconstructed")

    plt.subplot(2,2,4)
    plt.imshow(image_error, cmap="gray")
    plt.title("Error")

    plt.tight_layout()

    plt.savefig("dct_python_q{}.pdf".format(DCT_QUALITY))
    plt.show()

if __name__ == "__main__":
    # main('full')
    # main('block')
    main('block_fpga')
