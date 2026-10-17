#!/usr/bin/env python3
"""Cuts the small sizes (16, 24, 32, 48 px) out of the app icon into app/assets/tray.ico.

    python installer/make-tray-icon.py

The tray icon is loaded at the size Windows asks for (16 px at 100 % scaling, 32 px at 200 %), so the
file needs only the small images; the full app icon is 130 KB with sizes up to 256 px. The images are
copied as they are (no new drawing): rerun this after scripts/gen-icon.py has made a new app_icon.ico.
"""
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "app", "windows", "runner", "resources", "app_icon.ico")
DST = os.path.join(ROOT, "app", "assets", "tray.ico")
SIZES = {16, 24, 32, 48}

data = open(SRC, "rb").read()
count = struct.unpack("<H", data[4:6])[0]
images = []
for i in range(count):
    w, h, colors, reserved, planes, bits, size, offset = struct.unpack("<BBBBHHII", data[6 + 16 * i : 22 + 16 * i])
    if (w or 256) in SIZES:
        images.append((w, h, colors, reserved, planes, bits, data[offset : offset + size]))

out = bytearray(struct.pack("<HHH", 0, 1, len(images)))
offset = 6 + 16 * len(images)
for w, h, colors, reserved, planes, bits, blob in images:
    out += struct.pack("<BBBBHHII", w, h, colors, reserved, planes, bits, len(blob), offset)
    offset += len(blob)
for *_, blob in images:
    out += blob
open(DST, "wb").write(out)
print("wrote %s: %d images, %d bytes" % (DST, len(images), len(out)))
