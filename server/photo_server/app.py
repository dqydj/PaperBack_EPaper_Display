"""Simple App to demonstrate Photos shared to an EPaper Display.

A quick hack to display random images to an internet connected ESP32 ->
ePaper Display Bridge "Paperback".  It uses the body of the response to dump
bytes from an image.

Don't do this in production.  I'll rewrite it to be RESTful later.

Author: PK
Link: https://github.com/dqydj/PaperBack_EPaper_Display
License: MIT
Best practices followed: None.

"""
from flask import Flask
from PIL import Image, ImageOps
from optparse import OptionParser
import sys

SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
BYTE_LENGTH = 8

app = Flask(__name__)


@app.route('/')
def hello_world():
    return convert_image("images/dqydj.bmp")

def convert_image(imagepath):
    """Convert an image to fit on Paperback."""

    # Open the image, convert it to color, and fit it to the screen
    im = Image.open(imagepath)
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
            stripped = avg_bright & 0B11110000
            color_byte.append("{0:04b}".format(stripped >> 4))

            stripped = avg_bright & 0B11110000
            pixels[k, i] = (int(stripped), int(stripped), int(stripped))

            if len(color_byte) >= 2:
                color_byte_list.append(''.join(color_byte))
                color_byte = []

    out_string = ""
    for entry in color_byte_list:
        out_string += str(int(entry, 2)) + "\r"
    return out_string
