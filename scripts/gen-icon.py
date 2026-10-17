"""Omnitun app icon v5: a knight's shield in the manner of Oscar of Astora's in Dark Souls 1 — a heater
shield with a deep-blue field, a worn gold rim, a gold cross and pinstripe, a gold boss with a keyhole
(a last ember in it), on a dark ground. Everything is drawn here, with lighting from a height map.
Writes the Android adaptive icon layers, legacy PNGs, a Windows .ico and a 1024 px master.

    python scripts/gen-icon.py <repo root>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1]
M = 1024          # master size
SS = 2            # supersampling for the masters
rng = np.random.default_rng(11)


def bezier(p0, p1, p2, p3, n=64):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = (np.array(p, float) for p in (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def heater():
    """A heater shield in unit coordinates (x -0.86..0.86, y -0.82..1.0, y down), a closed polygon."""
    right = np.vstack([
        bezier((0, -0.82), (0.3, -0.82), (0.6, -0.82), (0.80, -0.82)),
        bezier((0.80, -0.82), (0.84, -0.82), (0.86, -0.80), (0.86, -0.76)),
        bezier((0.86, -0.76), (0.86, -0.4), (0.86, -0.1), (0.86, 0.10)),
        bezier((0.86, 0.10), (0.86, 0.58), (0.46, 0.84), (0, 1.0)),
    ])
    left = right[::-1] * np.array([-1, 1])
    return np.vstack([right, left])


SHAPE = heater()


def poly_mask(N, cx, cy, scale, shrink=1.0, dy=0.0):
    m = Image.new("L", (N, N), 0)
    pts = [(cx + x * scale * shrink, cy + (y * shrink + dy) * scale) for x, y in SHAPE]
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def arr(img):
    return np.asarray(img, np.float32) / 255.0


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return arr(img)


def noise(N, radius, seed_scale=1.0):
    """Soft noise in 0..1."""
    raw = rng.random((N // 4, N // 4)).astype(np.float32)
    img = Image.fromarray((raw * 255).astype(np.uint8), "L").resize((N, N), Image.BICUBIC)
    a = blur(arr(img), radius)
    a = (a - a.min()) / max(a.max() - a.min(), 1e-6)
    return a


def shield(N, size, mono=False):
    """The shield on a transparent N px canvas; size = its height as a fraction of N."""
    scale = N * size / 1.82           # the shape is 1.82 units tall
    cx, cy = N / 2, N / 2 - 0.09 * scale + 0.0 * N
    rim_w = 0.13                       # the width of the iron rim, in units

    outer = arr(poly_mask(N, cx, cy, scale))
    inner = arr(poly_mask(N, cx, cy, scale, shrink=1 - rim_w / 0.9))
    pin_out = arr(poly_mask(N, cx, cy, scale, shrink=1 - (rim_w + 0.045) / 0.9))
    pin_in = arr(poly_mask(N, cx, cy, scale, shrink=1 - (rim_w + 0.075) / 0.9))
    pin = np.clip(inner - pin_out, 0, 1) * 0 + np.clip(pin_out - pin_in, 0, 1)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    ux, uy = (xx - cx) / scale, (yy - cy) / scale          # unit coordinates

    # the cross: a vertical and a horizontal band over the field
    bw = 0.085
    cross_y = -0.12
    band = np.maximum(np.abs(ux) < bw, np.abs(uy - cross_y) < bw * 0.95).astype(np.float32) * inner
    # the boss: a round iron dome where the bands meet, with a ring round it
    br = np.hypot(ux, uy - cross_y)
    boss = (br < 0.215).astype(np.float32)
    boss_ring = ((br < 0.255) & (br >= 0.215)).astype(np.float32)
    # the keyhole in it
    ky = uy - cross_y
    hole = ((np.hypot(ux, ky + 0.035) < 0.058) |
            ((ky > -0.02) & (ky < 0.135) & (np.abs(ux) < 0.016 + (ky + 0.02) * 0.14))).astype(np.float32)
    # rivets along the rim
    rivets = np.zeros((N, N), np.float32)
    rim_mid = 1 - (rim_w / 0.9) / 2
    ring = SHAPE * rim_mid
    seg = np.hypot(*np.diff(np.vstack([ring, ring[:1]]), axis=0).T)
    along = np.concatenate([[0], np.cumsum(seg)])
    for t in np.linspace(0, along[-1], 22, endpoint=False):
        i = int(np.searchsorted(along, t))
        x, y = ring[min(i, len(ring) - 1)]
        px, py = cx + x * scale, cy + y * scale
        rr = 0.019 * scale
        rivets[(xx - px) ** 2 + (yy - py) ** 2 < rr * rr] = 1.0

    if mono:
        # one colour, for the themed icon: rim, bands, boss ring and rivets; keyhole and field are empty
        a = np.clip(outer * (1 - inner) + band + boss_ring + pin, 0, 1) * outer
        a = np.clip(a - hole, 0, 1)
        white = np.full((N, N, 3), 255, np.uint8)
        return Image.fromarray(np.dstack([white, (a * 255).astype(np.uint8)]), "RGBA")

    # height map for the lighting
    s1 = N / 1024
    dome = boss * np.clip(1 - (br / 0.215) ** 2, 0, 1)
    h = (0.55 * blur(outer, 10 * s1) + 0.35 * blur(inner, 7 * s1) + 0.25 * blur(band, 4 * s1)
         + 0.25 * blur(boss, 5 * s1) + 0.30 * blur(dome, 6 * s1) + 0.12 * blur(pin, 2 * s1) + 0.20 * blur(boss_ring, 2.5 * s1)
         - 0.55 * blur(hole, 2.2 * s1) + 0.20 * blur(rivets, 1.5 * s1))
    h += (noise(N, 1.2 * s1) - 0.5) * 0.012                      # pitted metal
    gy, gx = np.gradient(h * 14.0)
    # light from the upper left, a little in front
    shade = np.clip(0.5 + (-gx * 0.62 - gy * 0.78) * 0.9, 0, 1)
    spec = np.clip((-gx * 0.62 - gy * 0.78) - 0.35, 0, 1) ** 1.6

    # colours of the materials
    iron_rim = np.array((206, 164, 74), np.float32)     # the gold rim
    iron_field = np.array((30, 60, 142), np.float32)    # the deep blue field
    gold = np.array((192, 152, 68), np.float32)         # cross and pinstripe
    boss_c = np.array((216, 176, 84), np.float32)
    base = iron_field[None, None] * np.ones((N, N, 1), np.float32)
    base = np.where((outer > 0.5)[..., None] & (inner < 0.5)[..., None], iron_rim, base)
    base = np.where((pin > 0.5)[..., None], gold, base)
    base = np.where((band > 0.5)[..., None], gold, base)
    base = np.where((boss > 0.5)[..., None], boss_c, base)
    base = np.where((boss_ring > 0.5)[..., None], gold * 0.78, base)
    base = np.where((rivets > 0.5)[..., None], np.array((222, 190, 112), np.float32), base)
    base = np.where((hole > 0.5)[..., None], np.array((8, 8, 12), np.float32), base)

    # wear: dark grime in the corners and along the edge, scratches, a dusting of rust and verdigris
    grime = noise(N, 40 * s1)
    edge_wear = np.clip(blur(outer, 4 * s1) - blur(outer, 22 * s1), 0, 1)
    mottled = 0.86 + 0.22 * noise(N, 6 * s1)
    scratches = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(scratches)
    for _ in range(70):
        x0, y0 = rng.random() * N, rng.random() * N
        ang = rng.normal(0.9, 0.5)
        ln = (0.04 + rng.random() * 0.14) * N
        d.line((x0, y0, x0 + np.cos(ang) * ln, y0 + np.sin(ang) * ln), fill=int(60 + rng.random() * 150), width=max(1, int(1.2 * s1)))
    scr = arr(scratches.filter(ImageFilter.GaussianBlur(0.6 * s1)))
    rim_zone = (outer > 0.5) & (inner < 0.5)
    ao = 1 - 0.55 * np.clip(blur(1 - inner, 26 * s1) * 1.4, 0, 1) * (inner > 0.5)      # the field darkens near the rim
    rust = np.clip((noise(N, 9 * s1) - 0.58) * 4.0, 0, 1) * rim_zone
    tarnish = np.clip((noise(N, 5 * s1) - 0.45) * 3.0, 0, 1) * (band > 0.5)
    base = base * (1 - 0.35 * tarnish[..., None]) + tarnish[..., None] * np.array((70, 52, 26), np.float32) * 0.35
    base = base * (1 - 0.45 * rust[..., None]) + rust[..., None] * np.array((84, 60, 28), np.float32) * 0.45
    lit = (0.30 + 1.0 * shade)[..., None] * ao[..., None]
    rgb = base * lit * mottled[..., None] * (1 - 0.42 * grime[..., None])
    rgb = rgb + spec[..., None] * np.array((255, 226, 150), np.float32) * 0.5
    rgb = rgb + edge_wear[..., None] * np.array((110, 92, 52), np.float32) * 0.42     # bright metal on the rim edge
    rgb = rgb + scr[..., None] * np.array((190, 170, 120), np.float32) * 0.2 * (outer > 0.5)[..., None]
    # the ember in the keyhole: a last warm light, the only colour in the icon
    glow = blur(hole, 14 * s1) * 0.9
    rgb = rgb + glow[..., None] * np.array((255, 120, 40), np.float32) * 0.55 * (1 - hole[..., None])
    rgb = np.where((hole > 0.5)[..., None], rgb + np.array((190, 80, 24), np.float32) * 0.5 * np.clip(1 - np.abs(ky + 0.035) / 0.2, 0, 1)[..., None], rgb)

    out = np.dstack([np.clip(rgb, 0, 255), outer * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    # a thin dark edge to separate it from the ground
    return img


def drop_shadow(N, size):
    scale = N * size / 1.82
    cx, cy = N / 2, N / 2 - 0.09 * scale
    m = arr(poly_mask(N, cx + 0.02 * scale, cy + 0.04 * scale, scale))
    a = blur(m, 30 * N / 1024) * 0.7
    black = np.zeros((N, N, 3), np.uint8)
    return Image.fromarray(np.dstack([black, (a * 255).astype(np.uint8)]), "RGBA")


def background(N):
    """A dark ground: cold charcoal, lighter behind the shield, fogged at the edges."""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    r = np.hypot((xx - N / 2) / N, (yy - N * 0.46) / N)
    t = np.clip(r / 0.75, 0, 1)
    c0, c1 = np.array((22, 32, 58), np.float32), np.array((4, 7, 16), np.float32)
    base = c0[None, None] * (1 - t[..., None]) + c1[None, None] * t[..., None]
    fog = noise(N, 60 * N / 1024)
    base = base * (0.9 + 0.2 * fog[..., None])
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


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
fg_size = 0.645
fg = down(Image.alpha_composite(drop_shadow(N, fg_size), shield(N, fg_size)), M)
mono = down(shield(N, fg_size, mono=True), M)
bg = down(background(N), M)

# legacy / store icon: everything together, the shield bigger
big = 0.86
legacy = down(Image.alpha_composite(Image.alpha_composite(background(N), drop_shadow(N, big)), shield(N, big)), M)

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
ico = os.path.join(ROOT, "app", "windows", "runner", "resources", "app_icon.ico")
master.save(ico, format="ICO", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
print("wrote ico")
