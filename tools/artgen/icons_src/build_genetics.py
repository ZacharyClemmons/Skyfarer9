"""Writes ../ui_icons_genetics.txt: 16x16 HUD icons for the genetic powers (tg's
/datum/action/cooldown/spell icons for each power_path) and the DNA console's genome
images (tg dna_undiscovered / dna_discovered / dna_extra).

Same conventions as build_v2.py: a 1 px outline round everything, each colour layer lit
on its top-left edges and shaded on its bottom-right ones, one or two white glints.

Run: py build_genetics.py   (then py ../gen.py ui)
"""
import math
import os

import numpy as np

YY, XX = np.mgrid[0:16, 0:16]
LETTERS = [c for c in "abcdefghijklmnpqrstuvxyzABCDEFGHIJKLMNPQRSTUVXYZ123456789"]


# ------------------------------------------------------------------ colour helpers
def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def _hex(c):
    return "#%02x%02x%02x" % tuple(int(max(0, min(255, v))) for v in c)


def tone(h, amt):
    c = _rgb(h)
    if amt >= 0:
        return _hex([v + (255 - v) * amt for v in c])
    return _hex([v * (1 + amt) for v in c])


# ------------------------------------------------------------------ shapes
def empty():
    return np.zeros((16, 16), bool)


def disc(cx, cy, r):
    return (XX + 0.5 - cx) ** 2 + (YY + 0.5 - cy) ** 2 <= r * r


def ellipse(cx, cy, rx, ry):
    return ((XX + 0.5 - cx) / rx) ** 2 + ((YY + 0.5 - cy) / ry) ** 2 <= 1.0


def rect(x0, y0, x1, y1):
    return (XX >= x0) & (XX <= x1) & (YY >= y0) & (YY <= y1)


def line(x0, y0, x1, y1, w=1.0):
    """A capsule from (x0, y0) to (x1, y1), pixel centres, `w` wide."""
    px, py = XX.astype(float), YY.astype(float)
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy or 1.0
    t = np.clip(((px - x0) * dx + (py - y0) * dy) / L2, 0, 1)
    d = np.hypot(px - (x0 + t * dx), py - (y0 + t * dy))
    return d <= w / 2.0 + 0.01


def poly(pts):
    m = empty()
    n = len(pts)
    for y in range(16):
        for x in range(16):
            px, py = x + 0.5, y + 0.5
            inside = False
            j = n - 1
            for i in range(n):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            m[y, x] = inside
    return m


def pts(lst):
    m = empty()
    for x, y in lst:
        m[y, x] = True
    return m


# ------------------------------------------------------------------ the icon builder
ICONS = []  # (name, header colour, extra colours, rows)


def icon(name, layers, glints=(), flat=()):
    """layers: [(mask, hex)] bottom to top; each gets its own light / base / shade letters.
    `flat` layer indices skip the edge shading (thin lines and details)."""
    grid = [["."] * 16 for _ in range(16)]
    extra = {}
    letters = iter(LETTERS)
    union = empty()
    for li, (m, col) in enumerate(layers):
        lt, bs, sh = next(letters), next(letters), next(letters)
        extra[lt], extra[bs], extra[sh] = tone(col, 0.4), col, tone(col, -0.35)
        for y in range(16):
            for x in range(16):
                if not m[y, x]:
                    continue
                if li in flat:
                    grid[y][x] = bs
                    continue
                up = y == 0 or not m[y - 1, x]
                lf = x == 0 or not m[y, x - 1]
                dn = y == 15 or not m[y + 1, x]
                rt = x == 15 or not m[y, x + 1]
                grid[y][x] = sh if (dn or rt) and not (up or lf) else (lt if (up or lf) else (sh if (dn or rt) else bs))
        union |= m
    for y in range(16):
        for x in range(16):
            if not union[y, x] and any(0 <= y + dy < 16 and 0 <= x + dx < 16 and union[y + dy, x + dx]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                grid[y][x] = "o"
    for x, y in glints:
        grid[y][x] = "w"
    ICONS.append((name, layers[0][1], extra, ["".join(r) for r in grid]))


# ------------------------------------------------------------------ the powers
SKIN = "#e0ac8a"


def eye(iris):
    white = disc(8, 16.5, 10.5) & disc(8, -0.5, 10.5) & rect(1, 4, 14, 11)
    ir = disc(8, 8, 3.2) & white
    pupil = rect(7, 7, 8, 8)
    return white, ir, pupil


w, ir, pu = eye("#ff6a2a")
icon("gp_thermal_vision", [(w, "#e8eef4"), (ir, "#ff5a2a"), (pu, "#1a1418")], glints=[(9, 6)], flat=[2])

w, ir, pu = eye("#5ab8ff")
rays = line(0, 2, 2, 4) | line(15, 2, 13, 4) | line(0, 13, 2, 11) | line(15, 13, 13, 11)
icon("gp_farsight", [(rays, "#7fd4ff"), (w, "#e8eef4"), (ir, "#3a8ad8"), (pu, "#1a1418")], glints=[(9, 6)], flat=[0, 3])

flake = empty()
for k in range(3):
    a = math.pi / 2 + k * math.pi / 3
    dx, dy = math.cos(a) * 6.2, math.sin(a) * 6.2
    flake |= line(7.5 - dx, 7.5 - dy, 7.5 + dx, 7.5 + dy, 1.2)
    for s in (-1, 1):
        bx, by = 7.5 + s * math.cos(a) * 4, 7.5 + s * math.sin(a) * 4
        for b in (-1, 1):
            ba = a + b * math.pi / 4 + (0 if s > 0 else math.pi)
            flake |= line(bx, by, bx + math.cos(ba) * 2.2, by + math.sin(ba) * 2.2, 1.0)
icon("gp_snow", [(flake, "#cfeeff")], flat=[0])

beam = line(2, 13, 11, 4, 2.2)
burst = disc(11.5, 4.5, 3.2)
icon("gp_cryo", [(beam, "#5ac8ff"), (burst, "#bfeeff")], glints=[(11, 3)])
icon("gp_pyro", [(beam, "#ff7a2a"), (burst, "#ffd84a")], glints=[(11, 3)])

pile = ellipse(8, 12.5, 6.5, 3) | ellipse(8, 10, 3.5, 2.5)
flecks = pts([(6, 11), (10, 12), (8, 9), (4, 13), (12, 13)])
icon("gp_ash", [(pile, "#9a9aa2"), (flecks, "#4a4a52")], flat=[1])

flame = disc(8, 10.5, 4.6) | poly([(3.8, 9), (8, 0.8), (12.2, 9)]) | poly([(10, 6), (13, 2.5), (12.5, 9)])
core = disc(8, 11.5, 2.4) | poly([(6.2, 11), (8, 5.5), (9.8, 11)])
icon("gp_fire_breath", [(flame, "#ff6a2a"), (core, "#ffd84a")])

heart = disc(5.3, 6, 3.4) | disc(10.7, 6, 3.4) | poly([(1.9, 6.8), (14.1, 6.8), (8, 14)])
bolt = poly([(9, 2), (5, 8.5), (8, 8.5), (6.5, 14), (11, 6.5), (8, 6.5), (10, 2)])
icon("gp_adrenaline", [(heart, "#e8404a"), (bolt, "#ffe24a")])

arm = line(3, 12.5, 12.5, 3, 3.4)
hand = disc(12.5, 3, 2.3)
cut = line(6.2, 5.8, 9.8, 9.6, 1.0) & arm
icon("gp_self_amputation", [(arm, SKIN), (hand, SKIN), (cut, "#c8203a")], flat=[2])

nose = poly([(5, 1.5), (7, 1.5), (10, 10), (10, 12.5), (5, 12.5), (4, 10.5), (6, 9.5)])
nostril = pts([(6, 11), (7, 11)])
scent = pts([(12, 3), (13, 4), (12, 5), (13, 6), (12, 7), (14, 9), (15, 10), (14, 11)])
icon("gp_olfaction", [(nose, SKIN), (nostril, "#6a3a2a"), (scent, "#7ae8a8")], flat=[1, 2])

head = disc(5.5, 8.5, 4.3) | rect(3, 11, 8, 14)
waves = (disc(6, 8.5, 7.8) & ~disc(6, 8.5, 6.8) & (XX >= 11)) | (disc(6, 8.5, 10.2) & ~disc(6, 8.5, 9.2) & (XX >= 13))
icon("gp_telepathy", [(head, "#8a93a3"), (waves, "#c87aff")], flat=[1])

brain = disc(5.5, 8, 4.8) | disc(10.5, 8, 4.8)
brain &= ~rect(0, 13, 15, 15)
folds = pts([(8, 3), (8, 4), (8, 5), (8, 6), (8, 7), (8, 8), (8, 9), (8, 10), (8, 11),
             (4, 6), (5, 7), (4, 9), (11, 6), (12, 7), (11, 10), (12, 9)])
icon("gp_mindread", [(brain, "#f09ab8"), (folds, "#b8587a")], glints=[(4, 4)], flat=[1])

spike = poly([(2, 14.5), (3.5, 11), (13.5, 1.5), (5, 13)])
icon("gp_tongue_spike", [(spike, "#d86a8a")], glints=[(12, 3)])
tip = disc(13, 2.5, 2.2) & spike | pts([(12, 3), (13, 2), (11, 4)])
icon("gp_chem_spike", [(spike, "#9a6ac8"), (tip, "#5ae87a")], flat=[1])

drop = disc(6.5, 10, 4.2) | poly([(2.8, 9), (6.5, 1.5), (10.2, 9)])
arrow = line(10, 11, 14.5, 11, 1.4) | poly([(12.5, 8), (15.8, 11), (12.5, 14)])
icon("gp_send_chems", [(drop, "#4ad86a"), (arrow, "#e8eef4")], glints=[(5, 7)])

zap = poly([(10, 0.5), (3, 9), (7.5, 9), (5, 15.5), (13, 6), (8.5, 6), (11.5, 0.5)])
icon("gp_shock_touch", [(zap, "#8ae8ff")], glints=[(9, 3)])

palm = rect(4, 7, 11, 13) | disc(7.5, 13, 3.6)
fingers = rect(4, 3, 5, 7) | rect(6, 2, 7, 7) | rect(8, 2, 9, 7) | rect(10, 3, 11, 7) | line(3, 9, 1.5, 7, 1.8)
cross = rect(7, 8, 8, 13) | rect(5, 10, 10, 11)
icon("gp_lay_on_hands", [(palm | fingers, SKIN), (cross, "#3ad86a")], flat=[1])

void = disc(8, 8, 6.8)
rim = void & ~disc(8, 8, 5.2)
core2 = disc(8, 8, 2.2)
icon("gp_void_cursed", [(void, "#1a0e28"), (rim, "#9a4ae8"), (core2, "#050308")], flat=[2])

web = empty()
for k in range(6):
    a = k * math.pi / 3 + 0.3
    web |= line(7.5, 7.5, 7.5 + math.cos(a) * 7.4, 7.5 + math.sin(a) * 7.4, 0.9)
for r in (3.2, 6.0):
    for k in range(6):
        a0 = k * math.pi / 3 + 0.3
        a1 = a0 + math.pi / 3
        web |= line(7.5 + math.cos(a0) * r, 7.5 + math.sin(a0) * r, 7.5 + math.cos(a1) * r, 7.5 + math.sin(a1) * r, 0.9)
icon("gp_lay_web", [(web, "#dfe6ee")], flat=[0])


# ------------------------------------------------------------------ genome images (tg dna_*.png)
def helix(col_a, col_b, rung):
    a, b, r = empty(), empty(), empty()
    for y in range(1, 15):
        t = (y - 1) / 13 * math.tau * 1.0
        xa = 7.5 + 4.2 * math.sin(t)
        xb = 7.5 - 4.2 * math.sin(t)
        a[y, int(round(xa))] = True
        b[y, int(round(xb))] = True
        if y % 2 == 0:
            lo, hi = sorted((int(round(xa)), int(round(xb))))
            for x in range(lo + 1, hi):
                r[y, x] = True
    return [(r, rung), (b, col_b), (a, col_a)]


icon("genome_undiscovered", helix("#9a9aa2", "#6a6a72", "#4a4a52"), flat=[0, 1, 2])
icon("genome_discovered", helix("#5ae87a", "#3a9ad8", "#2a5a4a"), flat=[0, 1, 2])
icon("genome_extra", helix("#d88aff", "#8a5ae8", "#4a2a6a"), flat=[0, 1, 2])


if __name__ == "__main__":
    out = ["# Generated by icons_src/build_genetics.py - edit that file, not this one.", ""]
    for name, col, extra, rows in ICONS:
        out.append("@%s %s %s" % (name, col, " ".join("%s=%s" % (k, v) for k, v in extra.items())))
        out += rows
        out.append("")
    with open(os.path.join(os.path.dirname(__file__), "..", "ui_icons_genetics.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("wrote %d icons" % len(ICONS))
