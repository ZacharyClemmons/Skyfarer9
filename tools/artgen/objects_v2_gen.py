"""Station objects: tg genetics (dna_scanner.dm, dna_console.dm) and what the genetic powers
leave behind (ash, webbing, the void mutation's hole)."""
import math

import numpy as np

from common import hexc, mix, shade
from objects_v2 import (NEW, E, H, R, P, _sp, cabinet, done, fill, ground, lamp, screen, sheen)
from px import shade_mask

GENE = "#5ad88a"  # tg genetics green-teal on the scanner trim and console screen


def dna_scanner(state_open, occupied=False, powered=True):
    """tg's DNA scanner: an upright capsule with a curved glass door on the front, a base with
    the genetics stripe, and a status lamp. Open, the door slides up into the hood."""
    sp = _sp()
    cv = sp.cv
    ground(cv, 5, 26, 30)
    # base plinth
    cabinet(cv, 5, 24, 26, 29, 2, "#8a93a3", "metal")
    # the capsule shell
    shell = R(cv, 6, 3, 25, 25, 6)
    shade_mask(cv, shell, "#d8dee6", "plastic", bevel=3)
    cv.hline(7, 24, 22, H(GENE))
    cv.hline(7, 24, 23, shade(H(GENE), -0.35))
    # the chamber mouth
    mouth = R(cv, 9, 6, 22, 20, 4)
    fill(cv, mouth, "#1c2028")
    inner = R(cv, 10, 7, 21, 19, 3)
    shade_mask(cv, inner, "#39414e", "metal", bevel=2)
    if occupied:
        # a figure standing inside, lit by the scanner
        head = E(cv, 15.5, 9.5, 2.6, 2.4)
        shade_mask(cv, head, "#c89a7a", "cloth", bevel=1.2)
        body = R(cv, 12, 12, 19, 19, 2)
        shade_mask(cv, body, "#6a7486", "cloth", bevel=1.2)
    if not state_open:
        # the glass door covers the mouth
        door = R(cv, 9, 6, 22, 20, 4)
        tint = "#5ad8b0" if powered else "#6a8a90"
        a = np.zeros_like(cv.a)
        a[door] = [*hexc(tint)[:3], 0.45]
        m = door & (a[:, :, 3] > 0)
        cv.a[m] = cv.a[m] * (1 - 0.45) + a[m] * 0.45
        cv.a[m, 3] = 1.0
        for i in range(4):
            sheen(cv, 11 + i, 8 + i, 0.55)
            sheen(cv, 12 + i, 8 + i, 0.3)
        cv.vline(15, 6, 20, mix(H("#1c2028"), H(tint), 0.4))  # the door seam
    else:
        # the door retracted into the hood: a band of glass above the mouth
        band = R(cv, 9, 3, 22, 5, 1)
        shade_mask(cv, band, "#5ad8b0" if powered else "#6a8a90", "glass", bevel=1)
    if powered:
        for x in range(11, 21):
            sp.g(x, 7, mix(hexc(GENE), hexc("#39414e"), 0.35))
        lamp(sp, 23, 26, "#ff6a4a" if occupied and not state_open else "#5aff7a")
        lamp(sp, 8, 26, GENE)
    else:
        cv.px(23, 26, H("#3a2a2a"))
    return done(sp)


NEW["dna_scanner"] = lambda: dna_scanner(False)
NEW["dna_scanner_open"] = lambda: dna_scanner(True)
NEW["dna_scanner_occupied"] = lambda: dna_scanner(False, True)
NEW["dna_scanner_unpowered"] = lambda: dna_scanner(False, False, False)
NEW["dna_scanner_open_unpowered"] = lambda: dna_scanner(True, False, False)


def console_dna():
    """tg's DNA console: the standard console with the genetics screen, a double helix on it."""
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    fp, tp, _ = cabinet(cv, 4, 24, 27, 37, 6, "#4a505e", "metal", top="#6b7486")
    cv.hline(5, 26, 33, H(GENE))
    cv.hline(5, 26, 34, shade(H(GENE), -0.35))
    for y in (26, 28):
        for x in range(7, 25, 2):
            cv.px(x, y, H("#c8d0dc"))
            cv.px(x, y + 1, H("#2a2e38"))
    lamp(sp, 23, 26, "#5aff7a")
    lamp(sp, 25, 26, "#6a9aff")
    mp, _, _ = cabinet(cv, 5, 3, 26, 22, 2, "#5a6272", "metal", top="#7a8494")
    screen(sp, 8, 7, 23, 19, "#1f5a4a", "text", "dnacon")
    # the helix on the screen: two strands crossing, with rungs
    cv.rect(8, 7, 23, 19, H("#0c1c1a"))
    for y in range(8, 19):
        t = (y - 8) / 11 * math.tau * 1.25
        xa = 15.5 + 5 * math.sin(t)
        xb = 15.5 - 5 * math.sin(t)
        front_a = math.cos(t) > 0
        if y % 2 == 0:
            lo, hi = sorted((int(round(xa)), int(round(xb))))
            for x in range(lo + 1, hi):
                sp.g(x, y, hexc("#3a6a70"))
        sp.g(int(round(xa)), y, hexc("#5affb0") if front_a else hexc("#2a8a60"))
        sp.g(int(round(xb)), y, hexc("#2a6aa0") if front_a else hexc("#5ab8ff"))
    for y in range(8, 19, 2):
        cv.px(6, y, mp[0])
        cv.px(25, y, mp[0])
    return done(sp)


NEW["console_dna"] = console_dna


def ash():
    """A little heap of grey ash with a few darker flecks."""
    sp = _sp()
    cv = sp.cv
    heap = E(cv, 16, 21, 8, 4)
    shade_mask(cv, heap, "#8a8a8e", "cloth", bevel=2.5, noise=0.25, seed=7)
    rng = np.random.default_rng(3)
    for _ in range(14):
        x, y = int(rng.integers(9, 24)), int(rng.integers(18, 25))
        if heap[y, x]:
            cv.px(x, y, H("#4a4a50") if rng.random() < 0.6 else H("#c8c8cc"))
    for (x, y) in ((6, 24), (26, 22), (24, 26), (8, 19)):
        cv.px(x, y, H("#7a7a80"))
    return done(sp)


NEW["ash"] = ash


def stickyweb():
    """tg's sticky web: radial strands with rings between them, spanning the tile."""
    sp = _sp()
    cv = sp.cv
    c = hexc("#e8eef4", 0.8)
    cx, cy = 16, 16
    for k in range(8):
        a = k / 8 * math.tau + 0.2
        for r in range(1, 15):
            x, y = int(round(cx + math.cos(a) * r)), int(round(cy + math.sin(a) * r))
            if 0 <= x < 32 and 0 <= y < 32:
                cv.px(x, y, c)
    for ring in (4, 8, 12):
        for k in range(8):
            a0 = k / 8 * math.tau + 0.2
            a1 = (k + 1) / 8 * math.tau + 0.2
            for s in range(ring + 2):
                t = s / (ring + 1)
                # strands sag a little between spokes
                x = cx + (math.cos(a0) * (1 - t) + math.cos(a1) * t) * ring * (1 - 0.12 * math.sin(t * math.pi))
                y = cy + (math.sin(a0) * (1 - t) + math.sin(a1) * t) * ring * (1 - 0.12 * math.sin(t * math.pi))
                cv.px(int(round(x)), int(round(y)), hexc("#dfe6ee", 0.7))
    return sp


NEW["stickyweb"] = stickyweb


def void_hole():
    """The void mutation's hole in reality: a person-shaped patch of starless black with a
    purple fringe."""
    sp = _sp()
    cv = sp.cv
    shape = E(cv, 16, 9, 4, 4) | R(cv, 11, 12, 21, 22, 3) | R(cv, 12, 21, 20, 29, 2)
    fill(cv, shape, "#050308")
    edge = shape & ~(np.roll(shape, 1, 0) & np.roll(shape, -1, 0) & np.roll(shape, 1, 1) & np.roll(shape, -1, 1))
    for y, x in zip(*np.nonzero(edge)):
        sp.g(int(x), int(y), hexc("#9a4ae8", 0.8))
    for (x, y) in ((14, 16), (18, 20), (16, 25)):
        cv.px(x, y, H("#2a1a3a"))
    return sp


NEW["void_hole"] = void_hole
