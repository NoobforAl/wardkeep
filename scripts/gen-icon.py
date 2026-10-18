"""Wardkeep app icon v6: the shield of Oscar of Astora in Dark Souls 1 — a kite-shaped shield with a thin
worn silver rim, a deep navy field and ornate gold relief: a small crest in a laurel wreath, two leafy
branches rising from the point, filigree in the corners. Everything is drawn here as masks and lit from
a height map (bevel, scratches, wear), on a dark night-blue ground.
Writes the Android adaptive icon layers, legacy PNGs and a Windows .ico, and a 1024 px master.

    python scripts/gen-icon.py <repo root>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1]
M = 1024          # master size
SS = 2            # supersampling for the masters
rng = np.random.default_rng(7)


def bezier(p0, p1, p2, p3, n=64):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = (np.array(p, float) for p in (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def kite():
    """The shield in unit coordinates (x -0.84..0.84, y -0.86..1.0, y down), a closed polygon: a wide,
    slightly arched top with pointed corners, sides that curve in to a long point."""
    right = np.vstack([
        bezier((0, -0.87), (0.30, -0.87), (0.62, -0.84), (0.84, -0.78)),
        bezier((0.84, -0.78), (0.86, -0.3), (0.80, 0.05), (0.62, 0.38)),
        bezier((0.62, 0.38), (0.46, 0.68), (0.20, 0.88), (0, 1.0)),
    ])
    left = right[::-1] * np.array([-1, 1])
    return np.vstack([right, left])


SHAPE = kite()
HEIGHT_UNITS = 1.87


def poly_mask(N, pts):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    return m


def arr(img):
    return np.asarray(img, np.float32) / 255.0


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return arr(img)


def noise(N, radius):
    raw = rng.random((N // 4, N // 4)).astype(np.float32)
    img = Image.fromarray((raw * 255).astype(np.uint8), "L").resize((N, N), Image.BICUBIC)
    a = blur(arr(img), radius)
    return (a - a.min()) / max(a.max() - a.min(), 1e-6)


class Canvas:
    """Unit coordinates (the shield's) to pixels, and the drawing of the relief as one mask."""

    def __init__(self, N, size):
        self.N = N
        self.scale = N * size / HEIGHT_UNITS
        self.cx = N / 2
        self.cy = N / 2 - 0.07 * self.scale          # the shape's middle is at y = 0.07
        self.img = Image.new("L", (N, N), 0)
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y):
        return (self.cx + x * self.scale, self.cy + y * self.scale)

    def pts(self, points):
        return [self.px(x, y) for x, y in points]

    def line(self, a, b, w):
        self.d.line([self.px(*a), self.px(*b)], fill=255, width=max(1, int(w * self.scale)))

    def curve(self, points, w):
        self.d.line(self.pts(points), fill=255, width=max(1, int(w * self.scale)), joint="curve")

    def polygon(self, points):
        self.d.polygon(self.pts(points), fill=255)

    def circle(self, x, y, r, fill=255):
        cx, cy = self.px(x, y)
        r *= self.scale
        self.d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)

    def leaf(self, x, y, angle, length, width):
        """A pointed leaf from (x, y) in the direction [angle] (radians, 0 = right, y down)."""
        t = np.linspace(0, 1, 18)
        half = width / 2 * np.sin(np.pi * t) ** 0.75 * (1 - 0.25 * t)
        u = t * length
        top = np.stack([u, -half], axis=1)
        bottom = np.stack([u[::-1], half[::-1]], axis=1)
        pts = np.vstack([top, bottom])
        c, s = np.cos(angle), np.sin(angle)
        rot = np.stack([pts[:, 0] * c - pts[:, 1] * s + x, pts[:, 0] * s + pts[:, 1] * c + y], axis=1)
        self.polygon(rot)

    def mask(self):
        return arr(self.img)


def branch_points(side):
    """One branch of the laurel, from the point of the shield up to the upper corner; side is -1 or 1."""
    p = bezier((0.03, 0.80), (0.30, 0.62), (0.58, 0.30), (0.52, -0.10), n=40)
    q = bezier((0.52, -0.10), (0.48, -0.36), (0.40, -0.52), (0.30, -0.64), n=24)
    pts = np.vstack([p, q[1:]])
    pts[:, 0] *= side
    return pts


def ornament(N, size):
    """The gold relief as a mask: crest, wreath, two branches, corner filigree."""
    c = Canvas(N, size)
    # the two branches, with leaves along them on both sides, and a bud at the tip
    for side in (-1, 1):
        pts = branch_points(side)
        c.curve(pts, 0.016)
        for i in range(4, len(pts) - 2, 3):
            x, y = pts[i]
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
            ang = np.arctan2(dy, dx)
            k = i / len(pts)
            ln = 0.15 - 0.05 * k
            wd = 0.062 - 0.016 * k
            c.leaf(x, y, ang - 0.75, ln, wd)
            c.leaf(x, y, ang + 0.75, ln, wd)
        x, y = pts[-1]
        c.circle(x, y, 0.026)
        c.leaf(x, y, np.arctan2(pts[-1][1] - pts[-3][1], pts[-1][0] - pts[-3][0]), 0.12, 0.05)
    # the wreath round the crest: a ring with small leaves leaning round it
    cx, cy = 0.0, -0.13
    ring = np.array([[cx + 0.285 * np.cos(a), cy + 0.285 * np.sin(a)] for a in np.linspace(0, 2 * np.pi, 90)])
    c.curve(np.vstack([ring, ring[:1]]), 0.012)
    for k in range(16):
        a = k / 16 * 2 * np.pi
        x, y = cx + 0.285 * np.cos(a), cy + 0.285 * np.sin(a)
        tangent = a + np.pi / 2          # all the leaves run the same way round, like a wreath
        c.leaf(x, y, tangent + 0.5, 0.135, 0.058)
        c.leaf(x, y, tangent - 0.5, 0.135, 0.058)
    # the crest: a small shield
    crest = SHAPE * 0.185 + np.array([cx, cy - 0.01])
    c.polygon(crest)
    c.d.polygon(c.pts(SHAPE * 0.142 + np.array([cx, cy - 0.005])), fill=0)      # a hollow in it
    c.polygon(SHAPE * 0.085 + np.array([cx, cy - 0.005]))
    # the corner filigree: a bracket and a small triangle in each upper corner, a chevron at the point
    for sgn in (-1, 1):
        c.polygon([(sgn * 0.70, -0.70), (sgn * 0.50, -0.70), (sgn * 0.70, -0.50)])
        c.line((sgn * 0.70, -0.70), (sgn * 0.34, -0.72), 0.022)
        c.line((sgn * 0.70, -0.70), (sgn * 0.72, -0.30), 0.022)
        c.polygon([(sgn * 0.57, -0.60), (sgn * 0.47, -0.68), (sgn * 0.45, -0.60), (sgn * 0.5, -0.52)])
    c.polygon([(0, 0.93), (-0.09, 0.80), (0, 0.84), (0.09, 0.80)])
    return c.mask()


def inner_mask(N, size, rim_w):
    """The field: the shield shrunk by the rim's width (about its middle)."""
    c = Canvas(N, size)
    mid = np.array([0.0, 0.07])
    pts = (SHAPE - mid) * (1 - rim_w / 0.95) + mid
    c.polygon(pts)
    return c.mask()


def outer_mask(N, size):
    c = Canvas(N, size)
    c.polygon(SHAPE)
    return c.mask()


def shield(N, size, mono=False):
    """The shield on a transparent N px canvas; size = its height as a fraction of N."""
    s1 = N / 1024
    outer = outer_mask(N, size)
    field = inner_mask(N, size, 0.055)
    orn = ornament(N, size) * field
    rim = np.clip(outer - field, 0, 1)

    if mono:
        # one colour, for the themed icon: the rim and the relief; the field stays empty
        a = np.clip(rim + orn, 0, 1)
        white = np.full((N, N, 3), 255, np.uint8)
        return Image.fromarray(np.dstack([white, (a * 255).astype(np.uint8)]), "RGBA")

    # height map: the rim is raised, the gold relief stands on the field, a pitted metal grain over all
    h = 0.55 * blur(outer, 8 * s1) + 0.30 * blur(field, 6 * s1) + 0.55 * blur(orn, 2.2 * s1) + 0.18 * blur(orn, 6 * s1)
    h += (noise(N, 1.1 * s1) - 0.5) * 0.015
    gy, gx = np.gradient(h * 14.0)
    lightness = -gx * 0.62 - gy * 0.78                       # light from the upper left
    shade = np.clip(0.5 + lightness * 0.9, 0, 1)
    spec = np.clip(lightness - 0.3, 0, 1) ** 1.5

    silver = np.array((196, 202, 214), np.float32)
    navy = np.array((34, 44, 112), np.float32)
    gold = np.array((228, 184, 78), np.float32)
    base = navy[None, None] * np.ones((N, N, 1), np.float32)
    base = np.where((rim > 0.5)[..., None], silver, base)
    base = np.where((orn > 0.5)[..., None], gold, base)

    # wear: a paint-like mottling on the blue, darker grime in the folds, tarnish in the gold, the
    # silver rubbed through here and there, a few scratches
    mottle = 0.86 + 0.28 * noise(N, 5 * s1)
    grime = noise(N, 38 * s1)
    ao = 1 - 0.5 * np.clip(blur(1 - field, 30 * s1) * 1.5, 0, 1) * (field > 0.5)       # the field darkens near the rim
    tarnish = np.clip((noise(N, 4 * s1) - 0.5) * 3.0, 0, 1) * (orn > 0.5)
    base = base * (1 - 0.35 * tarnish[..., None]) + tarnish[..., None] * np.array((92, 66, 28), np.float32) * 0.35
    wear = np.clip((noise(N, 3 * s1) - 0.62) * 4.0, 0, 1) * (rim > 0.5)
    base = base * (1 - 0.55 * wear[..., None]) + wear[..., None] * np.array((82, 86, 98), np.float32) * 0.55

    scr = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(scr)
    for _ in range(60):
        x0, y0 = rng.random() * N, rng.random() * N
        ang = rng.normal(0.9, 0.5)
        ln = (0.04 + rng.random() * 0.12) * N
        d.line((x0, y0, x0 + np.cos(ang) * ln, y0 + np.sin(ang) * ln), fill=int(60 + rng.random() * 150), width=max(1, int(1.1 * s1)))
    scratches = arr(scr.filter(ImageFilter.GaussianBlur(0.6 * s1)))

    lit = ((0.34 + 1.0 * shade) * ao)[..., None]
    rgb = base * lit * mottle[..., None] * (1 - 0.30 * grime[..., None])
    rgb = rgb + spec[..., None] * np.array((255, 236, 170), np.float32) * 0.8 * (orn > 0.5)[..., None]    # gold glints
    rgb = rgb + spec[..., None] * np.array((230, 236, 250), np.float32) * 0.35 * (rim > 0.5)[..., None]    # silver glints
    rgb = rgb + scratches[..., None] * np.array((200, 205, 220), np.float32) * 0.22 * (outer > 0.5)[..., None]

    out = np.dstack([np.clip(rgb, 0, 255), outer * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def drop_shadow(N, size):
    c = Canvas(N, size)
    c.cx += 0.02 * c.scale
    c.cy += 0.04 * c.scale
    c.polygon(SHAPE)
    a = blur(c.mask(), 30 * N / 1024) * 0.7
    black = np.zeros((N, N, 3), np.uint8)
    return Image.fromarray(np.dstack([black, (a * 255).astype(np.uint8)]), "RGBA")


def background(N):
    """A dark ground: night blue, lighter behind the shield, fogged at the edges."""
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

# adaptive layers: 108 dp canvas, a launcher shows a circle of 66-72 dp (61-67 %) at most. The shield's
# upper corners are 0.64 of its height from its middle, so its height must stay under ~0.52 of the canvas
# for the whole shield to be inside that circle.
fg_size = 0.50
fg = down(Image.alpha_composite(drop_shadow(N, fg_size), shield(N, fg_size)), M)
mono = down(shield(N, fg_size, mono=True), M)
bg = down(background(N), M)

# legacy / store icon: everything together; the round variant is a full circle, so the corners need the
# same room (0.64 * 0.72 = 0.46 of the icon from the middle, under the 0.5 radius)
big = 0.72
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
