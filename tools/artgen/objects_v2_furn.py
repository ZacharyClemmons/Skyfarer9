"""Station objects, second generation: furniture, storage, vending and consoles (see objects_v2.py)."""
import numpy as np

from common import hexc, mix, ramp, rng_for, shade
from objects_v2 import (sheen, DARK_STEEL, GUNMETAL, REDRAWN, RUBBER, STEEL, E, H, P, R, _sp, cabinet, cyl_cols, done, door,
                        fill, ground, lamp, obj, panel, rod, screen, slits)
from px import shade_mask, sphere_height

WHITE = hexc("#ffffff")


# ============================================================================ beds
BED_SHEETS = ["#3a6ad8", "#c83a3a", "#3a9a5a", "#d8a53a", "#8a5ac8", "#e8eef4"]


def bed(sheet):
    sp = _sp()
    cv = sp.cv
    ground(cv, 3, 28, 30)
    # metal frame: the rails, and the short legs showing below the front rail
    for lx in (4, 27):
        cv.rect(lx, 27, lx, 29, H("#4a505e"))
    cabinet(cv, 3, 3, 28, 28, 23, "#7a8494", "metal", top="#8a93a3", bevel=1.0)
    # headboard across the top
    hb = cabinet(cv, 3, 1, 28, 5, 2, "#5a6272", "metal", bevel=1.0)
    # mattress
    shade_mask(cv, R(cv, 5, 6, 26, 25, 1), "#e8eef4", "cloth", bevel=2)
    # pillow: plump, with a crease
    pil = R(cv, 7, 7, 24, 11, 2)
    pp = shade_mask(cv, pil, "#f6f8fc", "cloth", height=sphere_height(pil))
    cv.hline(12, 19, 9, pp[1])
    # blanket: pulled up to the pillow, a folded-back band, draping over the foot
    bm = R(cv, 5, 13, 26, 27, 1)
    bp = shade_mask(cv, bm, sheet, "cloth", bevel=2.2)
    fold = R(cv, 5, 13, 26, 15, 1)
    shade_mask(cv, fold, "#f0f2f6", "cloth", bevel=1)
    cv.hline(5, 26, 16, bp[0])
    # one soft fold running down from the turned-back sheet
    for y in range(18, 25):
        cv.px(17 + (y - 18) // 3, y, bp[1])
    # the front drape
    cv.hline(5, 26, 26, bp[1])
    cv.hline(5, 26, 27, bp[0])
    return done(sp)


for _i, _c in enumerate(BED_SHEETS):
    REDRAWN[f"bed_{_i}"] = (lambda c: (lambda: bed(c)))(_c)


# ============================================================================ lockers
LOCKER = {"eng": ("#d8a53a", "#5f6878"), "med": ("#e8eef4", "#4aa3d8"), "sec": ("#8a2a33", "#d8d0c0"),
          "sci": ("#7a5ab8", "#e8eef4"), "gen": ("#6a7486", "#9aa3b3"), "emerg": ("#3a6ad8", "#e8eef4"),
          "fire": ("#c83a3a", "#e8e8e8"), "winter": ("#3a8a9a", "#eaf8ff"), "cmd": ("#3a5ab8", "#d8b84a")}


def locker(kind, open_=False):
    col, stripe = LOCKER[kind]
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 6, 25, 46)
    fp, tp, _ = cabinet(cv, 6, 6, 25, 45, 4, col, "paint")
    if open_:
        # the empty inside: back wall, a shelf, a hanging rail with a hanger
        inside = H("#1a1920")
        cv.rect(8, 11, 23, 43, inside)
        cv.rect(9, 12, 22, 42, H("#24232c"))
        cv.hline(9, 22, 13, H("#3a3944"))
        cv.hline(9, 22, 20, H("#5a6272"))
        cv.hline(9, 22, 21, H("#2a2e38"))
        cv.px(15, 22, H("#8a93a3"))
        cv.hline(13, 17, 23, H("#8a93a3"))
        cv.hline(9, 22, 42, fp[1])
        # the door, swung open towards us: a thin slab on the right edge
        dm = P(cv, [(25, 10), (29, 12), (29, 46), (25, 45)])
        dp = shade_mask(cv, dm, col, "paint", bevel=1)
        cv.vline(26, 12, 44, dp[-1])
        cv.vline(28, 14, 44, dp[0])
        cv.px(27, 28, H("#c8d0dc"))
    else:
        dp = door(cv, 8, 11, 23, 43, col)
        # vents up top and a small intake at the bottom
        slits(cv, 11, 20, (14, 17, 20), dp)
        slits(cv, 11, 20, (38,), dp)
        # department stripe down the door
        cv.rect(10, 23, 11, 35, H(stripe))
        cv.vline(10, 23, 35, shade(H(stripe), 0.2))
        # lock panel with its status light, and the handle
        cv.rect(19, 24, 22, 28, H("#3a3f4a"))
        cv.hline(19, 22, 24, H("#6b7486"))
        lamp(sp, 20, 26, "#5aff7a")
        cv.rect(20, 30, 21, 34, H("#c8d0dc"))
        cv.vline(21, 30, 34, H("#6b7486"))
        # rivets
        for (x, y) in ((9, 12), (22, 12), (9, 42), (22, 42)):
            cv.px(x, y, dp[0])
    return done(sp)


for _k in LOCKER:
    REDRAWN[f"locker_{_k}"] = (lambda k: (lambda: locker(k)))(_k)
    REDRAWN[f"locker_{_k}_open"] = (lambda k: (lambda: locker(k, True)))(_k)


# ============================================================================ vending machines
VENDING = {"snack": ("#3a6ad8", "#ffd84a"), "cocoa": ("#7a4a2e", "#ffb87a"), "drink": ("#c83a3a", "#e8f4ff"),
           "med": ("#e8eef4", "#4ab8d8"), "tool": ("#d8a53a", "#2a2e38"), "winter": ("#3a8a9a", "#eaf8ff")}
PRODUCTS = {
    "snack": ["#e84a4a", "#ffd84a", "#4ae86a", "#ff8a3a", "#e8e8e8"],
    "cocoa": ["#8a5a3a", "#e8d8b8", "#c83a3a", "#6a3a22"],
    "drink": ["#3a8ae8", "#e84a4a", "#4ae86a", "#e8e8e8", "#ffd84a"],
    "med": ["#e8eef4", "#4ab8d8", "#e84a4a", "#8ad85a"],
    "tool": ["#e8b830", "#c8342e", "#8a93a3", "#3a8ae8"],
    "winter": ["#3a8a9a", "#e8eef4", "#c83a3a", "#e8a83a"],
}


def vending(kind):
    col, sign = VENDING[kind]
    sp = _sp(32, 48)
    cv = sp.cv
    rng = rng_for("v2vend" + kind)
    ground(cv, 5, 26, 46)
    fp, tp, _ = cabinet(cv, 5, 4, 26, 45, 3, col, "paint")
    # lit marquee
    for y in range(8, 12):
        for x in range(8, 24):
            c = H(sign) if y in (9, 10) else shade(H(sign), -0.35)
            sp.g(x, y, c)
    for x in range(9, 23, 3):
        cv.px(x, 9, shade(H(sign), 0.3))
    # the glass front: dark interior, shelves of product, a diagonal glare
    gx0, gx1, gy0, gy1 = 7, 19, 14, 36
    cv.rect(gx0 - 1, gy0 - 1, gx1 + 1, gy1 + 1, fp[0])
    cv.rect(gx0, gy0, gx1, gy1, H("#16202c"))
    prods = PRODUCTS[kind]
    for row in range(4):
        y = gy0 + 1 + row * 6
        cv.hline(gx0, gx1, y + 4, H("#6b7486"))
        cv.hline(gx0, gx1, y + 5, H("#2a2e38"))
        for i, x in enumerate(range(gx0 + 1, gx1 - 1, 3)):
            pc = H(prods[(row * 3 + i + rng.randint(0, 1)) % len(prods)])
            if kind in ("drink", "med"):
                cv.rect(x, y + 1, x + 1, y + 3, pc)
                cv.px(x, y + 1, shade(pc, 0.35))
                cv.px(x + 1, y + 3, shade(pc, -0.35))
            else:
                cv.rect(x, y, x + 1, y + 3, pc)
                cv.px(x, y, shade(pc, 0.3))
                cv.px(x + 1, y + 2, shade(pc, -0.4))
            # a glow wash from the interior light
            sp.glow.px(x, y + 2, mix(pc, H("#000000"), 0.7))
    sp.has_glow = True
    for i in range(12):
        x, y = gx0 + 2 + i, gy1 - 2 - i * 2
        if gx0 <= x <= gx1 and gy0 <= y <= gy1:
            sheen(cv, x, y, 0.28)
            if y - 1 >= gy0:
                sheen(cv, x, y - 1, 0.14)
    # control column: little screen, keypad, coin slot
    screen(sp, 22, 15, 24, 17, "#5ad0ff", "text", "vk" + kind)
    for y in (20, 22, 24):
        for x in (21, 23):
            cv.px(x, y, fp[-1])
            cv.px(x, y + 1, fp[0])
    cv.rect(22, 28, 23, 31, H("#15141c"))
    cv.px(22, 28, H("#3a3f4a"))
    # dispense flap
    cv.rect(8, 39, 18, 42, H("#15141c"))
    cv.hline(8, 18, 39, H("#3a3f4a"))
    cv.hline(8, 18, 43, fp[-1])
    return done(sp)


for _k in VENDING:
    REDRAWN[f"vending_{_k}"] = (lambda k: (lambda: vending(k)))(_k)


# ============================================================================ consoles
CONSOLE = {"eng": "#d8a53a", "med": "#4ab8d8", "sec": "#d84a4a", "sci": "#b87ae8", "cmd": "#4a8ad8",
           "reactor": "#2ad8a8", "cargo": "#e8a84a", "atmos": "#5ad0ff", "comms": "#8ad85a"}


def console(kind):
    col = CONSOLE[kind]
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 4, 27, 38)
    # the body: a desk cabinet with a sloped keyboard deck
    fp, tp, _ = cabinet(cv, 4, 24, 27, 37, 6, "#4a505e", "metal", top="#6b7486")
    cv.hline(5, 26, 33, H(col))
    cv.hline(5, 26, 34, shade(H(col), -0.35))
    for y in (26, 28):
        for x in range(7, 25, 2):
            cv.px(x, y, H("#c8d0dc"))
            cv.px(x, y + 1, H("#2a2e38"))
    lamp(sp, 23, 26, "#5aff7a")
    lamp(sp, 25, 26, col)
    # the monitor housing, leaning back slightly
    mp, _, _ = cabinet(cv, 5, 3, 26, 22, 2, "#5a6272", "metal", top="#7a8494")
    style = {"reactor": "graph", "sec": "map", "atmos": "graph", "med": "graph", "comms": "bars", "eng": "bars"}.get(kind, "text")
    screen(sp, 8, 7, 23, 19, col, style, "v2con" + kind)
    # vents on the housing sides
    for y in range(8, 19, 2):
        cv.px(6, y, mp[0])
        cv.px(25, y, mp[0])
    return done(sp)


for _k in CONSOLE:
    REDRAWN[f"console_{_k}"] = (lambda k: (lambda: console(k)))(_k)


# ============================================================================ kitchen & comfort
@obj("fridge")
def fridge():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 5, 26, 46)
    fp, _, _ = cabinet(cv, 5, 4, 26, 45, 3, "#dfe5ee", "plastic")
    d1 = door(cv, 7, 9, 24, 19, "#e8edf4", "plastic")
    d2 = door(cv, 7, 22, 24, 43, "#e8edf4", "plastic")
    for (y0, y1) in ((11, 17), (24, 34)):
        cv.rect(22, y0, 22, y1, H("#9aa3b3"))
        cv.vline(21, y0, y1, H("#f8fbff"))
    cv.hline(6, 25, 20, fp[0])
    cv.hline(6, 25, 21, fp[1])
    screen(sp, 9, 11, 12, 12, "#5ad0ff", "text", "fridge")
    # a couple of magnets and a note
    cv.rect(10, 27, 13, 30, H("#f4ecc8"))
    cv.px(11, 27, H("#d84a4a"))
    cv.px(15, 25, H("#4a8ad8"))
    return done(sp)


@obj("filing_cabinet")
def filing_cabinet():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 8, 23, 38)
    fp, _, _ = cabinet(cv, 8, 9, 23, 37, 3, "#7a8494", "metal")
    for y0 in (13, 21, 29):
        dp = door(cv, 9, y0, 22, y0 + 6, "#8a93a3", "metal")
        cv.rect(14, y0 + 2, 17, y0 + 2, H("#dfe6ee"))
        cv.hline(14, 17, y0 + 3, dp[0])
        cv.rect(11, y0 + 1, 12, y0 + 2, H("#f4f0e0"))
    # a paper sticking out of the top drawer
    cv.rect(18, 12, 20, 13, H("#f4f0e8"))
    return done(sp)


@obj("water_cooler")
def water_cooler():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 10, 21, 38)
    fp, _, _ = cabinet(cv, 10, 20, 21, 37, 2, "#dfe5ee", "plastic")
    # the jug: a translucent blue bottle upside-down on top
    jug = R(cv, 11, 7, 20, 19, 3) | R(cv, 14, 19, 17, 21, 0)
    jp = cyl_cols(cv, jug, H("#4aa8e0"))
    cv.a[jug, 3] = 0.9
    for y in (10, 15):
        cv.hline(11, 20, y, jp[1])
    cv.hline(12, 19, 7, jp[-1])
    # water line and bubbles
    cv.hline(11, 20, 9, H("#8ad0f4"))
    cv.px(17, 13, H("#c8ecff"))
    cv.px(16, 17, H("#c8ecff"))
    # taps and the drip tray
    cv.rect(12, 25, 13, 26, H("#d84a4a"))
    cv.rect(18, 25, 19, 26, H("#4a8ad8"))
    cv.rect(12, 30, 19, 31, H("#5a6272"))
    cv.hline(12, 19, 30, H("#9aa3b3"))
    # a stack of paper cups
    cv.rect(21, 22, 22, 26, H("#f4f0e8"))
    return done(sp)


@obj("coffee_machine")
def coffee_machine():
    sp = _sp(32, 40)
    cv = sp.cv
    ground(cv, 8, 23, 38)
    fp, _, _ = cabinet(cv, 8, 9, 23, 37, 3, "#2e2e36", "metal", top="#4a4a56")
    # bean hopper on top
    hop = P(cv, [(10, 3), (21, 3), (19, 10), (12, 10)])
    shade_mask(cv, hop, "#b8d0dc", "glass", bevel=1)
    beans = P(cv, [(11, 6), (20, 6), (19, 10), (12, 10)])
    fill(cv, beans, H("#4a2a18"))
    for (x, y) in ((13, 7), (15, 8), (17, 7), (16, 9), (18, 8)):
        cv.px(x, y, H("#7a4a2a"))
    cv.hline(11, 20, 3, H("#e8f4ff"))
    # control strip
    screen(sp, 11, 14, 16, 15, "#ffb84a", "text", "coffee")
    lamp(sp, 19, 14, "#5aff7a")
    lamp(sp, 21, 14, "#ff4a3a")
    # brew bay with a mug under the spout
    cv.rect(10, 19, 21, 30, H("#121216"))
    cv.rect(14, 19, 17, 21, H("#6b7486"))
    cv.px(15, 22, H("#6a3a1a"))
    mug = R(cv, 13, 25, 18, 30, 1)
    mp = shade_mask(cv, mug, "#e8e0cc", "plastic")
    cv.hline(14, 17, 25, H("#4a2a14"))
    cv.px(19, 27, mp[1])
    cv.px(19, 28, mp[1])
    cv.rect(10, 31, 21, 32, H("#6b7486"))
    cv.hline(10, 21, 31, H("#a9b3c2"))
    return done(sp)


@obj("wardrobe")
def wardrobe():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 5, 26, 46)
    wood = "#6e4a2c"
    fp, _, _ = cabinet(cv, 5, 6, 26, 45, 3, wood, "paint", top="#8a6040")
    for (x0, x1) in ((7, 15), (16, 24)):
        dp = door(cv, x0, 11, x1, 42, wood)
        # recessed panels
        cv.rect(x0 + 2, 14, x1 - 2, 24, dp[1])
        cv.hline(x0 + 2, x1 - 2, 14, dp[0])
        cv.rect(x0 + 2, 28, x1 - 2, 39, dp[1])
        cv.hline(x0 + 2, x1 - 2, 28, dp[0])
        # wood grain
        for y in range(16, 39, 5):
            cv.px(x0 + 3 + (y % 3), y, dp[2])
    for x in (14, 17):
        cv.rect(x, 25, x, 27, H("#d8b050"))
    cv.px(14, 25, H("#fff0a0"))
    cv.px(17, 25, H("#fff0a0"))
    cv.hline(6, 25, 43, fp[0])
    return done(sp)


@obj("toilet")
def toilet():
    sp = _sp()
    cv = sp.cv
    ground(cv, 10, 21, 29)
    porcelain = "#eef2f8"
    # cistern against the wall, with its flush button
    cabinet(cv, 10, 4, 21, 11, 3, porcelain, "plastic")
    cv.px(15, 5, H("#9aa3b3"))
    cv.px(16, 5, H("#c8d0dc"))
    # the bowl: seat ring, then the water
    bowl = E(cv, 15.5, 19, 6.2, 6.8)
    shade_mask(cv, bowl, porcelain, "plastic", height=sphere_height(bowl))
    seat = E(cv, 15.5, 18.5, 5.2, 5.6)
    shade_mask(cv, seat & ~E(cv, 15.5, 18.5, 3.2, 3.8), "#f8fbff", "plastic", bevel=1)
    water = E(cv, 15.5, 18.8, 3.2, 3.8)
    shade_mask(cv, water, "#8ac8e8", "glass", bevel=1)
    cv.px(14, 17, H("#e8f8ff"))
    # the pedestal base
    cv.rect(13, 25, 18, 27, H("#c8d0dc"))
    cv.hline(13, 18, 27, H("#9aa3b3"))
    return done(sp)


@obj("jukebox")
def jukebox():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 6, 25, 46)
    wood = "#6a3a22"
    fp, _, _ = cabinet(cv, 6, 14, 25, 45, 3, wood, "paint", top="#8a5a3a")
    # the arched glass top with its neon tube
    arch = E(cv, 15.5, 17, 9.5, 11) & R(cv, 0, 6, 31, 17)
    shade_mask(cv, arch, "#c89050", "paint", bevel=2)
    inner = E(cv, 15.5, 17, 7, 8.5) & R(cv, 0, 8, 31, 17)
    cv.a[inner] = H("#2a1810")
    ring = E(cv, 15.5, 17, 8.2, 9.8) & ~E(cv, 15.5, 17, 7.2, 8.8) & R(cv, 0, 6, 31, 17)
    for y, x in zip(*np.nonzero(ring)):
        sp.g(x, y, H("#ff5a8a") if x < 16 else H("#ffb84a"))
    # the record inside
    rec = E(cv, 15.5, 14, 4, 2.2)
    fill(cv, rec, H("#141418"))
    cv.px(15, 14, H("#d84a4a"))
    cv.px(16, 14, H("#d84a4a"))
    # light bars
    for i, c in enumerate(("#ff5a8a", "#ffd84a", "#5ae8ff", "#7aff7a")):
        for x in range(9, 23):
            sp.g(x, 21 + i * 2, H(c) if x % 4 else shade(H(c), -0.3))
    # speaker grille and selector buttons
    cv.rect(9, 31, 22, 41, H("#2a160e"))
    for y in range(32, 41, 2):
        cv.hline(10, 21, y, H("#4a2a18"))
    for x in range(10, 22, 3):
        cv.px(x, 29, H("#e8d8b8"))
    return done(sp)


@obj("arcade")
def arcade():
    sp = _sp(32, 48)
    cv = sp.cv
    ground(cv, 7, 24, 46)
    body = "#2a2e52"
    fp, _, _ = cabinet(cv, 7, 6, 24, 45, 3, body, "paint")
    # marquee
    for y in range(10, 13):
        for x in range(9, 23):
            sp.g(x, y, H("#ff5a8a") if y != 11 else H("#ffd0e0"))
    cv.px(12, 11, H("#5ae8ff"))
    cv.px(19, 11, H("#5ae8ff"))
    # the screen, framed
    cv.rect(9, 14, 22, 26, H("#15141c"))
    screen(sp, 10, 15, 21, 25, "#7aff7a", "graph", "arcade")
    # a little ship and invaders on screen
    for (x, y, c) in ((15, 24, "#e8e8ff"), (16, 24, "#e8e8ff"), (12, 17, "#ff5a8a"), (15, 17, "#ff5a8a"), (18, 17, "#ff5a8a")):
        sp.g(x, y, H(c))
    # control deck: joystick and buttons, sticking out towards us
    cabinet(cv, 8, 28, 23, 33, 3, "#3a3f6a", "paint")
    cv.rect(11, 26, 11, 29, H("#2a2e38"))
    ball = E(cv, 11.5, 26, 1.6, 1.6)
    shade_mask(cv, ball, "#d83a3a", "plastic", height=sphere_height(ball))
    for (x, c) in ((16, "#e8d84a"), (18, "#4a8aff"), (20, "#5ad84a")):
        cv.px(x, 29, H(c))
        cv.px(x, 30, shade(H(c), -0.4))
    # coin door
    cv.rect(13, 37, 18, 41, fp[0])
    lamp(sp, 14, 38, "#ffb84a")
    lamp(sp, 17, 38, "#ffb84a")
    return done(sp)


# ============================================================================ chairs
CHAIRS = {"steel": ("#8a93a3", "#8a93a3"), "office": ("#2e3440", "#4a505e"), "wood": ("#8a5a3b", "#6e4a2c"),
          "comfy": ("#8a2e3e", "#5a3a2a"), "shuttle": ("#3a5a8a", "#6b7486")}


def chair(d, kind):
    seat_c, frame_c = CHAIRS[kind]
    mat = "cloth" if kind in ("office", "comfy", "shuttle") else ("paint" if kind == "wood" else "metal")
    sp = _sp()
    cv = sp.cv
    wide = kind == "comfy"
    x0, x1 = (8, 23) if wide else (9, 22)
    ground(cv, x0, x1, 29, 0.35)
    # legs / base
    if kind == "office":
        rod(cv, 15, 23, 16, 26, 1.0, "#3a3f4a", "metal")
        for (a, b) in ((10, 28), (21, 28), (15, 29), (12, 26), (19, 26)):
            rod(cv, 15.5, 26, a, b, 0.7, "#3a3f4a", "metal")
            cv.px(a, b, H(RUBBER))
    elif kind == "shuttle":
        cv.rect(14, 23, 17, 28, H("#4a505e"))
        cv.vline(14, 23, 28, H("#6b7486"))
    elif kind == "comfy":
        for x in (x0 + 1, x1 - 1):
            cv.rect(x, 26, x, 28, H("#3a2618"))
    else:
        for x in (x0 + 1, x1 - 1):
            cv.vline(x, 22, 28, H(frame_c) if kind == "wood" else H("#6b7486"))
            cv.px(x, 28, H("#3a3f4a"))
        for x in (x0 + 3, x1 - 3):
            cv.vline(x, 22, 26, shade(H(frame_c), -0.3))

    def back_s():
        fp, _, _ = cabinet(cv, x0 + (0 if wide else 0), 5, x1, 15, 2, seat_c, mat, bevel=1.4)
        if kind == "shuttle":
            for x in (x0 + 3, x1 - 3):
                cv.vline(x, 8, 22, H("#e8c83a"))
        if kind == "wood":
            for x in range(x0 + 2, x1 - 1, 3):
                cv.vline(x, 8, 14, fp[1])
        if kind == "office":
            cv.hline(x0 + 2, x1 - 2, 10, fp[1])

    def seat():
        cabinet(cv, x0, 15, x1, 23, 5, seat_c, mat, bevel=1.4)

    def arms():
        if wide:
            for ax in (x0 - 1, x1 - 2):
                cabinet(cv, ax, 11, ax + 3, 24, 3, seat_c, mat, bevel=1)

    if d == "s":
        back_s()
        seat()
        arms()
    elif d == "n":
        seat()
        arms()
        fp, _, _ = cabinet(cv, x0, 10, x1, 24, 2, seat_c, mat, bevel=1.6)
        if kind == "office":
            cv.rect(15, 18, 16, 23, fp[0])
        if kind == "wood":
            for x in range(x0 + 2, x1 - 1, 3):
                cv.vline(x, 13, 22, fp[1])
    else:
        seat()
        bx = x0 - 1 if d == "e" else x1 - 2
        cabinet(cv, bx, 5, bx + 3, 23, 2, seat_c, mat, bevel=1)
        if wide:
            ax = x1 - 3 if d == "e" else x0
            cabinet(cv, ax, 11, ax + 3, 24, 3, seat_c, mat, bevel=1)
    return done(sp)


for _k in CHAIRS:
    for _d in "nesw":
        REDRAWN[f"chair_{_k}_{_d}"] = (lambda k, d: (lambda: chair(d, k)))(_k, _d)
