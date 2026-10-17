"""Omnitun app icon v3: a shield with a keyhole, flat, in the app's cold blue. One simple
shape that still reads at 48 px (v2, a portal gate in a starfield, looked like a game).
Writes the Android adaptive icon layers, legacy PNGs, a Windows .ico, an in-app logo and
a 1024 px master.

    python scripts/gen-icon.py <repo root>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = sys.argv[1]
M = 1024          # master size
SS = 2            # supersampling for the masters


def bezier(p0, p1, p2, p3, n=48):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = (np.array(p, float) for p in (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def shield_outline():
    """The shield in unit coordinates (x -0.9..0.9, y -1..1, y down), as a closed polygon."""
    right = np.vstack([
        bezier((0, -1.0), (0.34, -0.90), (0.64, -0.80), (0.88, -0.70)),
        bezier((0.88, -0.70), (0.88, -0.35), (0.88, -0.1), (0.88, 0.12)),
        bezier((0.88, 0.12), (0.88, 0.58), (0.48, 0.84), (0, 1.0)),
    ])
    left = right[::-1] * np.array([-1, 1])
    return np.vstack([right, left])


SHIELD = shield_outline()


def to_px(poly, cx, cy, scale):
    return [(cx + x * scale, cy + y * scale) for x, y in poly]


def keyhole(draw, cx, cy, scale, fill):
    """A keyhole: a round head and a tapering stem, centred a little above the middle."""
    hy = cy - 0.13 * scale
    r = 0.19 * scale
    draw.ellipse((cx - r, hy - r, cx + r, hy + r), fill=fill)
    draw.polygon([
        (cx - 0.075 * scale, hy + 0.05 * scale), (cx + 0.075 * scale, hy + 0.05 * scale),
        (cx + 0.135 * scale, hy + 0.50 * scale), (cx - 0.135 * scale, hy + 0.50 * scale)], fill=fill)


def gradient(N, top, bottom):
    t = np.linspace(0, 1, N)[:, None, None]
    arr = np.array(top, float) * (1 - t) + np.array(bottom, float) * t
    return Image.fromarray(np.repeat(arr, N, axis=1).astype(np.uint8), "RGB").convert("RGBA")


def mask_of(N, draw_fn):
    m = Image.new("L", (N, N), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def badge(N, size, mono=False):
    """The shield on a transparent N px canvas; size = the shield's height as a fraction of N."""
    scale = N * size / 2
    cx, cy = N / 2, N / 2
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    outer = mask_of(N, lambda d: d.polygon(to_px(SHIELD, cx, cy, scale), fill=255))
    # the inner shield leaves a border of the rim colour; nudged down so the rim is even
    inner_scale = scale * 0.84
    inner = mask_of(N, lambda d: d.polygon(to_px(SHIELD, cx, cy + 0.01 * scale, inner_scale), fill=255))
    hole = mask_of(N, lambda d: keyhole(d, cx, cy + 0.01 * scale, inner_scale, 255))
    if mono:
        # one colour: the rim and the keyhole; the face between them is transparent
        a = np.array(outer, float) / 255
        a = a * (1 - np.array(inner, float) / 255) + np.array(hole, float) / 255
        white = np.full((N, N, 3), 255, np.uint8)
        return Image.fromarray(np.dstack([white, (np.clip(a, 0, 1) * 255).astype(np.uint8)]), "RGBA")
    rim = Image.new("RGBA", (N, N), (222, 232, 246, 255))
    face = gradient(N, (86, 134, 200), (38, 78, 140))
    out.paste(rim, (0, 0), outer)
    out.paste(face, (0, 0), inner)
    key = Image.new("RGBA", (N, N), (236, 243, 252, 255))
    out.paste(key, (0, 0), hole)
    return out


def background(N):
    """Flat deep blue, a little lighter at the top."""
    return gradient(N, (24, 40, 68), (10, 18, 34))


def rounded(img, frac):
    N = img.size[0]
    m = Image.new("L", (N * 2, N * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, N * 2 - 1, N * 2 - 1), radius=int(N * 2 * frac), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m.resize(img.size, Image.LANCZOS))
    return out


def down(img, n):
    return img.resize((n, n), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


N = M * SS

# adaptive layers: 108 dp canvas, content inside the central 66 dp (61 %)
fg = down(badge(N, 0.52), M)
mono = down(badge(N, 0.52, mono=True), M)
bg = down(background(N), M)

# legacy / store icon: everything together, the shield bigger
legacy = down(Image.alpha_composite(background(N), badge(N, 0.72)), M)

res = ("app", "android", "app", "src", "main", "res")
for name, k in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
    d = f"mipmap-{name}"
    save(down(rounded(legacy, 0.22), int(48 * k)), *res, d, "ic_launcher.png")
    save(down(rounded(legacy, 0.5), int(48 * k)), *res, d, "ic_launcher_round.png")
    save(down(fg, int(108 * k)), *res, d, "ic_launcher_foreground.png")
    save(down(mono, int(108 * k)), *res, d, "ic_launcher_monochrome.png")
    save(down(bg.convert("RGB"), int(108 * k)), *res, d, "ic_launcher_background.png")

master = rounded(legacy, 0.22)
save(master, "docs", "icon.png")
save(down(legacy, 256), "app", "assets", "logo.png")
ico = os.path.join(ROOT, "app", "windows", "runner", "resources", "app_icon.ico")
master.save(ico, format="ICO", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
print("wrote ico")
