"""Item icons: tg genetics (dna_injector.dm, chromosome.dm, disks, the sequence scanner),
monkey cubes, and what the genetic powers make (snow blocks, tongue spikes)."""
import numpy as np

from common import hexc, mix, shade
from items_v2 import NEW, W, _cv, ball, box, cyl, dots, glint, glowing, rod, _sheets
from px import capsule_mask, finish, poly_mask, rect_m, shade_mask


def _injector(used):
    """tg's DNA injector: a slim autoinjector, the barrel holding green DNA fluid (empty once
    used), a plunger cap at the grip end and a needle shroud at the head."""
    cv = _cv()
    rod(cv, 7, 25, 11, 21, 2.3, "#e8eef4", "plastic")  # plunger cap
    rod(cv, 10, 22, 20, 12, 2.6, "#cfe8f5", "glass")    # barrel
    if not used:
        fluid = capsule_mask(W, W, 12, 20, 19, 13, 1.6)
        shade_mask(cv, fluid, "#4ad88a", "glass", bevel=1)
        glint(cv, 14, 16, 0.6)
    rod(cv, 19, 13, 23, 9, 2.2, "#3a7ac8", "plastic")   # shroud
    cv.px(25, 7, hexc("#c8d0dc"))
    cv.px(24, 8, hexc("#8a93a3"))
    return finish(cv)


NEW["dnainjector"] = lambda: _injector(False)
NEW["dnainjector0"] = lambda: _injector(True)


CHROMO = {"stabilizer": "#5ab8ff", "synchronizer": "#ffd84a", "power": "#ff5a5a", "energy": "#5aff7a"}


def _chromosome(col):
    """tg's chromosome: an X of two stubby chromatids, pinched at the centromere."""
    cv = _cv()
    a = capsule_mask(W, W, 10, 9, 22, 24, 3.2)
    b = capsule_mask(W, W, 22, 9, 10, 24, 3.2)
    pal = shade_mask(cv, a | b, col, "plastic", bevel=2.5)
    # the centromere pinch and the band stripes
    for (x, y) in ((15, 16), (16, 16), (16, 17), (15, 17)):
        cv.px(x, y, pal[0])
    for t in (0.25, 0.75):
        for (x0, y0, x1, y1) in ((10, 9, 22, 24), (22, 9, 10, 24)):
            x = int(round(x0 + (x1 - x0) * t))
            y = int(round(y0 + (y1 - y0) * t))
            cv.px(x, y, pal[1])
            cv.px(x + 1, y, pal[1])
    glint(cv, 11, 10, 0.7)
    glint(cv, 21, 10, 0.5)
    return finish(cv)


for _k, _c in CHROMO.items():
    NEW["chromosome_" + _k] = (lambda c: (lambda: _chromosome(c)))(_c)


DISK = ["#3a6ad8", "#d84a4a", "#4ab83a", "#e8c83a", "#b87ae8", "#e8903a", "#4ab8d8", "#6a7486"]


def _disk(col):
    """A 3.5 inch floppy: coloured shell, metal shutter, paper label."""
    cv = _cv()
    pal, _ = box(cv, 8, 8, 24, 24, col, "plastic", 1, 1.5)
    box(cv, 12, 8, 20, 13, "#b0b8c4", "metal", 0, 1)
    cv.rect(17, 9, 18, 12, hexc("#3a3f4a"))
    box(cv, 10, 16, 22, 23, "#f4f0e8", "paper", 0, 1)
    for y in (18, 20):
        cv.hline(11, 20, y, hexc("#a8a098"))
    cv.px(22, 9, pal[0])
    return finish(cv)


for _i, _c in enumerate(DISK):
    NEW["datadisk%d" % _i] = (lambda c: (lambda: _disk(c)))(_c)


def _carton(col, label):
    """A cardboard carton, flaps closed, a coloured label band on the front."""
    cv = _cv()
    top = poly_mask(W, W, [(9, 9), (26, 9), (23, 13), (6, 13)])
    shade_mask(cv, top, "#d8b888", "paper", bevel=1)
    cv.line(8, 11, 24, 11, hexc("#a88858"))
    pal, _ = box(cv, 6, 13, 23, 27, "#c8a070", "paper", 0, 1.5)
    side = poly_mask(W, W, [(23, 13), (26, 9), (26, 23), (23, 27)])
    shade_mask(cv, side, "#a88050", "paper", bevel=1)
    box(cv, 7, 17, 22, 23, col, "paint", 0, 1)
    label(cv)
    return finish(cv)


def _disk_label(cv):
    for x in (10, 14, 18):
        box(cv, x, 18, x + 2, 21, "#3a6ad8", "plastic", 0, 1)
        cv.px(x + 1, 18, hexc("#b0b8c4"))


def _monkey_label(cv):
    # a little monkey face
    ball(cv, 14.5, 20, 2.6, 2.4, "#7a5230", "cloth")
    ball(cv, 14.5, 21, 1.7, 1.3, "#e2b98c", "cloth")
    dots(cv, ((13, 19), (16, 19)), "#1a1418")
    dots(cv, ((11, 19), (18, 19)), "#7a5230")
    cv.hline(19, 21, 20, hexc("#f4f0e8"))


NEW["box_disks"] = lambda: _carton("#e8eef4", _disk_label)
NEW["box_monkeycubes"] = lambda: _carton("#f4e0a0", _monkey_label)


def monkeycube():
    """tg's monkey cube: a small dehydrated brown cube."""
    cv = _cv()
    top = poly_mask(W, W, [(12, 13), (21, 13), (19, 16), (10, 16)])
    shade_mask(cv, top, "#a8784a", "cloth", bevel=1)
    pal, _ = box(cv, 10, 16, 19, 24, "#8a5a32", "cloth", 0, 1.2)
    side = poly_mask(W, W, [(19, 16), (21, 13), (21, 21), (19, 24)])
    shade_mask(cv, side, "#6a4222", "cloth", bevel=1)
    rng = np.random.default_rng(11)
    for _ in range(8):
        x, y = int(rng.integers(11, 19)), int(rng.integers(17, 24))
        cv.px(x, y, pal[0] if rng.random() < 0.5 else pal[-1])
    return finish(cv)


NEW["monkeycube"] = monkeycube


def gene_scanner():
    """tg's genetic sequence scanner: a handheld with a screen of sequence bars and a
    sampling tip."""
    cv = _cv()
    box(cv, 12, 20, 19, 27, "#3a3f4a", "rubber", 2, 1.5)
    pal, _ = box(cv, 9, 7, 22, 21, "#e8eef4", "plastic", 2, 2)
    box(cv, 14, 3, 17, 7, "#5a6272", "metal", 1, 1)
    box(cv, 11, 9, 20, 16, "#0c1c1a", "glass", 1, 1)
    pts = []
    bars = ((12, "#5affb0"), (13, "#5ab8ff"), (15, "#ff6a6a"), (16, "#ffd84a"), (18, "#5affb0"), (19, "#5ab8ff"))
    for x, c in bars:
        h = 2 + (x * 7) % 4
        for y in range(15 - h, 15):
            pts.append((x, y, c))
    dots(cv, ((11, 18), (13, 18)), "#3a7ac8")
    cv.hline(10, 21, 21, pal[0])
    finish(cv)
    return glowing(cv, pts)


NEW["gene_scanner"] = gene_scanner


def sheet_snow():
    return _sheets("#eef6ff", "cloth", n=1)


NEW["sheet_snow"] = sheet_snow


def _spike(col, tip):
    """The tongue spike mutation's thrown biomass spike: a curved fleshy barb."""
    cv = _cv()
    body = poly_mask(W, W, [(7, 25), (10, 22), (18, 12), (25, 6), (20, 14), (12, 25)])
    shade_mask(cv, body, col, "plastic", bevel=1.5)
    for (x, y) in ((23, 8), (24, 7), (22, 9)):
        cv.px(x, y, hexc(tip))
    for (x, y) in ((11, 22), (14, 18), (17, 15)):
        cv.px(x, y, shade(hexc(col), -0.3))
    return finish(cv)


NEW["tonguespike"] = lambda: _spike("#c86a7a", "#f4e0e0")
NEW["tonguespikechem"] = lambda: _spike("#8a6ac8", "#5aff7a")
