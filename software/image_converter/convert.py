"""Automatically convert and resize images to fit an E-Paper Display.

This utility takes an image, automatically resizes and centers it, and changes
the color depth to fit on Paperback.  The output file contains an array which
can be copied and pasted directly into a header file in the static image
greyscale firmware.

Example usage:

python convert.py -i paperback.png -o picture.h

# or

python convert.py -i paperback.png -p -o picture.h

# to add a preview.

Author: PK
Site: https://hackaday.io/project/21607-paperback-desktop-e-paper-monitor
License: MIT
"""
from PIL import Image, ImageOps
from optparse import OptionParser
import sys

SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
BYTE_LENGTH = 8


def main(argv=None):
    """Convert an image to fit on Paperback."""
    parser = OptionParser()
    parser.add_option('-i', action="store", dest="inputfile")
    parser.add_option('-o', action="store", dest="outputfile")
    parser.add_option(
        "-p",
        action="store_true",
        dest="preview",
        default=False
    )

    (opts, args) = parser.parse_args()

    if opts.inputfile is not None:
        inputfile = opts.inputfile
    else:
        print ("Use the -i option and pass an inputfile")
        return 1

    if opts.outputfile is not None:
        outputfile = opts.outputfile
    else:
        print ("Use the -o option and pass an outputfile")
        return 2

    # Open the image, convert it to color, and fit it to the screen
    im = Image.open(inputfile)
    im = im.convert('RGB')
    im.thumbnail((SCREEN_WIDTH, SCREEN_HEIGHT), Image.ANTIALIAS)

    # If the image is smaller than 800x600 (likely), paste it on a white
    # background equal to the screen size
    if (SCREEN_WIDTH != im.size[0] or SCREEN_HEIGHT != im.size[1]):
        background = Image.new(
            im.mode,
            (SCREEN_WIDTH, SCREEN_HEIGHT),
            0xFFFFFF
        )

        img_w, img_h = im.size
        bg_w, bg_h = background.size
        offset_n = (int((bg_w - img_w) / 2), int((bg_h - img_h) / 2))

        background.paste(im, offset_n)
        im = background

    pixels = im.load()
    color_byte_list = []
    color_byte = []

    # Loop pixel by pixel to carefully construct a 4-Bit color depth
    # image.  Also edit the pixels themselves.
    for i in range(0, im.size[1]):
        for k in range(0, im.size[0]):
            r, g, b = im.getpixel((k, i))
            avg_bright = ((r + g + b) // 3)
            #stripped = avg_bright & 0B11110000

            reversed_upper = (0B00010000 & avg_bright) << 3
            reversed_upper |= (0B00100000 & avg_bright) << 1
            reversed_upper |= (0B01000000 & avg_bright) >> 1
            reversed_upper |= (0B10000000 & avg_bright) >> 3
            stripped = reversed_upper

            color_byte.append("{0:04b}".format(stripped >> 4))

            stripped = avg_bright & 0B11110000
            pixels[k, i] = (int(stripped), int(stripped), int(stripped))

            if len(color_byte) >= 2:
                color_byte_list.append(''.join(color_byte))
                color_byte = []

    # Write out the output file.
    with open(outputfile, 'w+') as f:
        f.write(
            "const uint8_t img_bytes[(800*600)/2] = {\n"
        )
        for entry in color_byte_list:
            f.write("\t0B" + entry + ",\n")
        f.write(
            "};"
        )

    # If you use the -p flag, show a preview.
    if opts.preview:
        im.show()


if __name__ == "__main__":
    sys.exit(main())
