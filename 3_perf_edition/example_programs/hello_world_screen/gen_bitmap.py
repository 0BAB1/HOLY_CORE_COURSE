#!/usr/bin/env python3
# usage :
# pip install pillow
# python3 gen_bitmap.py tos.png

from PIL import Image
import sys
import os

# ================= CONFIG =================
OUT_NAME = "templeos_logo"   # C symbol name
TARGET_W = 320               # set to None to keep original
TARGET_H = 240               # set to None to keep original
# ==========================================

def rgb888_to_rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <image.png>")
        sys.exit(1)

    img = Image.open(sys.argv[1]).convert("RGB")

    if TARGET_W and TARGET_H:
        img = img.resize((TARGET_W, TARGET_H), Image.NEAREST)

    w, h = img.size
    pixels = img.load()

    print("#include <stdint.h>")
    print()
    print(f"#define {OUT_NAME.upper()}_W {w}")
    print(f"#define {OUT_NAME.upper()}_H {h}")
    print()
    print(f"const uint16_t {OUT_NAME}[{w * h}] = {{")

    for y in range(h):
        print("    ", end="")
        for x in range(w):
            r, g, b = pixels[x, y]
            p = rgb888_to_rgb565(r, g, b)
            print(f"0x{p:04X}, ", end="")
        print()

    print("};")

if __name__ == "__main__":
    main()
