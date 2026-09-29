"""Shared pixel-art helpers for the Artic9 procedural art generator.

Everything is drawn on float RGBA numpy canvases (0..1) and quantised on save.
The goal is hand-made looking pixel art: limited hue-shifted ramps, selective
outlines, top-left lighting, and tileable noise for organic surfaces.
"""
import colorsys
import os
import random
import zlib

import numpy as np
from PIL import Image

T = 32  # tile size in pixels
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx")


# ---------------------------------------------------------------- colours
def hexc(h, a=1.0):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [a])


def mix(a, b, t):
    return a * (1 - t) + b * t


def shade(c, amt):
    """Hue-shifted shading: negative amt darkens toward cool blue/purple,
    positive brightens toward warm yellow. This is what makes ramps look painted."""
    r, g, b = c[:3]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if amt < 0:
        # shift hue toward 0.66 (blue) while darkening
        target = 0.68
        h = h + (target - h) * min(1, -amt * 0.35) if abs(target - h) < 0.5 else h
        l = max(0, l * (1 + amt))
        s = min(1, s * (1 - amt * 0.25))
    else:
        target = 0.14
        dh = target - h
        if dh > 0.5:
            dh -= 1
        if dh < -0.5:
            dh += 1
        h = (h + dh * min(1, amt * 0.25)) % 1.0
        l = min(1, l + (1 - l) * amt)
        s = max(0, s * (1 - amt * 0.15))
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return np.array([r, g, b, c[3]])


def ramp(base, n=5, spread=0.55):
    """n-step ramp from dark to light around base (index n//2 == base)."""
    base = hexc(base) if isinstance(base, str) else base
    mid = n // 2
    return [shade(base, (i - mid) / mid * spread) if i != mid else base.copy() for i in range(n)]


# ---------------------------------------------------------------- noise
def value_noise(w, h, cell, seed=0, periodic=True):
    rng = np.random.default_rng(seed)
    gw, gh = max(1, w // cell), max(1, h // cell)
    grid = rng.random((gh + 1, gw + 1))
    if periodic:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    ys = np.linspace(0, gh, h, endpoint=False)
    xs = np.linspace(0, gw, w, endpoint=False)
    x0 = xs.astype(int)
    y0 = ys.astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x0 + 1)]
    c = grid[np.ix_(y0 + 1, x0)]
    d = grid[np.ix_(y0 + 1, x0 + 1)]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(w, h, seed=0, octaves=4, base_cell=16):
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    cell = base_cell
    for o in range(octaves):
        out += value_noise(w, h, max(1, cell), seed + o * 97) * amp
        tot += amp
        amp *= 0.5
        cell = max(1, cell // 2)
    return out / tot


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def quantize_ramp(field, pal, dither=True):
    """field: HxW in 0..1 -> RGBA image using palette list (dark..light)."""
    h, w = field.shape
    n = len(pal)
    f = np.clip(field, 0, 0.9999) * (n - 1)
    base = np.floor(f).astype(int)
    frac = f - base
    if dither:
        yy, xx = np.mgrid[0:h, 0:w]
        thr = BAYER4[yy % 4, xx % 4]
        base = base + (frac > thr).astype(int)
    else:
        base = base + (frac > 0.5).astype(int)
    base = np.clip(base, 0, n - 1)
    arr = np.array(pal)
    return arr[base]


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w=T, h=T):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4))

    @staticmethod
    def from_array(arr):
        c = Canvas(arr.shape[1], arr.shape[0])
        c.a = arr.copy()
        return c

    def copy(self):
        return Canvas.from_array(self.a)

    def px(self, x, y, c, alpha=None):
        if 0 <= x < self.w and 0 <= y < self.h:
            c = np.array(c, dtype=float)
            if alpha is not None:
                c = c.copy()
                c[3] = alpha
            if c[3] >= 0.999:
                self.a[y, x] = c
            else:
                self.blend_px(x, y, c)

    def blend_px(self, x, y, c):
        dst = self.a[y, x]
        sa = c[3]
        da = dst[3]
        oa = sa + da * (1 - sa)
        if oa <= 0:
            return
        rgb = (c[:3] * sa + dst[:3] * da * (1 - sa)) / oa
        self.a[y, x] = np.array([*rgb, oa])

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.a[y, x]
        return np.zeros(4)

    def rect(self, x0, y0, x1, y1, c):
        """inclusive rect"""
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.px(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.px(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def mask_fill(self, mask, c):
        c = np.array(c, dtype=float)
        if c[3] >= 0.999:
            self.a[mask] = c
        else:
            ys, xs = np.nonzero(mask)
            for y, x in zip(ys, xs):
                self.blend_px(x, y, c)

    def paste(self, other, ox=0, oy=0):
        for y in range(other.h):
            ty = y + oy
            if not 0 <= ty < self.h:
                continue
            for x in range(other.w):
                tx = x + ox
                if not 0 <= tx < self.w:
                    continue
                c = other.a[y, x]
                if c[3] > 0:
                    self.px(tx, ty, c)

    def alpha_mask(self):
        return self.a[:, :, 3] > 0.01

    def flip_h(self):
        return Canvas.from_array(self.a[:, ::-1])

    def image(self):
        arr = np.clip(self.a * 255 + 0.5, 0, 255).astype(np.uint8)
        return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------- shapes / masks
def rrect_mask(w, h, x0, y0, x1, y1, r=1):
    m = np.zeros((h, w), bool)
    for y in range(max(0, y0), min(h, y1 + 1)):
        for x in range(max(0, x0), min(w, x1 + 1)):
            dx = max(x0 + r - x, 0, x - (x1 - r))
            dy = max(y0 + r - y, 0, y - (y1 - r))
            if r == 0 or dx * dx + dy * dy <= r * r + 0.5:
                m[y, x] = True
    return m


def ellipse_mask(w, h, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def edge_light(mask, light=(-1, -1)):
    """Per pixel lighting term from mask shape: +1 on lit edges, -1 on shadow
    edges, 0 in the middle. Gives a soft 'pillow' shading for volumes."""
    h, w = mask.shape
    lx, ly = light
    res = np.zeros((h, w))
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            v = 0.0
            # distance to edge towards the light / away from the light
            for d in (1, 2):
                xl, yl = x + lx * d, y + ly * d
                if not (0 <= xl < w and 0 <= yl < h) or not mask[yl, xl]:
                    v += 0.5 / d
                xs, ys = x - lx * d, y - ly * d
                if not (0 <= xs < w and 0 <= ys < h) or not mask[ys, xs]:
                    v -= 0.55 / d
            res[y, x] = v
    return np.clip(res, -1, 1)


def shaded_fill(cv, mask, base, spread=0.35, light=(-1, -1), noise=None, levels=None):
    """Fill mask with base colour pillow-shaded into a 5 tone ramp."""
    pal = ramp(base, 5, spread)
    lt = edge_light(mask, light)
    field = 0.5 + lt * 0.42
    if noise is not None:
        field = field + noise
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=False)
    cv.a[mask] = img[mask]
    return pal


def sel_outline(cv, strength=0.55, color=None, only_outer=True):
    """Selective outline: each transparent pixel adjacent to an opaque pixel
    becomes a darkened, hue-shifted version of its neighbour."""
    a = cv.a
    h, w = a.shape[:2]
    alpha = a[:, :, 3] > 0.01
    out = a.copy()
    for y in range(h):
        for x in range(w):
            if alpha[y, x]:
                continue
            best = None
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx]:
                    best = a[ny, nx]
                    break
            if best is not None:
                if color is not None:
                    out[y, x] = np.array(color)
                else:
                    c = shade(best, -strength)
                    c = mix(c, hexc("#14121c"), 0.55)
                    c[3] = 1.0
                    out[y, x] = c
    cv.a = out
    return cv


def drop_shadow(cv, dx=1, dy=1, alpha=0.35):
    """Soft contact shadow below an object (for objects standing on floors)."""
    a = cv.a
    h, w = a.shape[:2]
    alpha_m = a[:, :, 3] > 0.01
    sh = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            if alpha_m[y, x]:
                ty, tx = y + dy, x + dx
                if 0 <= ty < h and 0 <= tx < w and not alpha_m[ty, tx]:
                    sh[ty, tx] = [0.05, 0.05, 0.12, alpha]
    res = Canvas.from_array(sh)
    res.paste(cv)
    cv.a = res.a
    return cv


def rng_for(name):
    return random.Random(zlib.crc32(name.encode()))


# ---------------------------------------------------------------- output
def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(img, Canvas):
        img = img.image()
    img.save(path)
    return path


def sheet(canvases, cols, cw=T, ch=T):
    rows = (len(canvases) + cols - 1) // cols
    s = Canvas(cols * cw, rows * ch)
    for i, c in enumerate(canvases):
        if c is None:
            continue
        s.paste(c, (i % cols) * cw, (i // cols) * ch)
    return s
