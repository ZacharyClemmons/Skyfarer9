"""Writes ../ui_icons_v2.txt: the HUD's 16x16 icons, drawn pixel by pixel.

Conventions (a pixel artist's, kept the same across the set so it reads as one family):
  o  outline, 1 px, everywhere
  +  light (top and left faces; the light comes from the upper left)
  #  base colour
  -  shade (bottom and right faces)
  =  deep shade (the darkest crease or underside)
  w  a glint of pure white, one or two pixels at most
  other letters are per-icon colours given in the header ("g=#9aa8b8")
Symmetric things (hearts, drops, stars) are symmetric to the pixel; round things use
proper pixel circles; nothing is left to a formula unless it's a clean circle.

Run: py build_v2.py   (then py ../gen.py ui)
"""
import os

import numpy as np

ICONS = []  # (name, header colour, extra colours, rows)


def add(name, col, rows, **extra):
    rows = [r for r in rows]
    assert len(rows) == 16, (name, len(rows))
    for i, r in enumerate(rows):
        assert len(r) == 16, (name, i, len(r), r)
    ICONS.append((name, col, extra, rows))


# ------------------------------------------------------------------ mask helpers (for round shapes)
def disc(cx, cy, r):
    yy, xx = np.mgrid[0:16, 0:16]
    return (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r


def shade_mask(m, glint=None):
    """Outline around the mask, light on top/left edges, shade on bottom/right edges."""
    g = [["."] * 16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if m[y, x]:
                up = y == 0 or not m[y - 1, x]
                lf = x == 0 or not m[y, x - 1]
                dn = y == 15 or not m[y + 1, x]
                rt = x == 15 or not m[y, x + 1]
                g[y][x] = "+" if (up or lf) and not (dn or rt) else ("-" if (dn or rt) else ("+" if (up or lf) else "#"))
            elif any(0 <= y + dy < 16 and 0 <= x + dx < 16 and m[y + dy, x + dx]
                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "o"
    if glint:
        for (x, y) in glint:
            g[y][x] = "w"
    return ["".join(r) for r in g]


def put(rows, pts, ch):
    g = [list(r) for r in rows]
    for (x, y) in pts:
        g[y][x] = ch
    return ["".join(r) for r in g]


# ============================================================================ hearts
HEART = [
    "................",
    "..oooo....oooo..",
    ".o++##o..o####o.",
    "o+w+###oo#####-o",
    "o++###########-o",
    "o+############-o",
    "o#############-o",
    ".o###########-o.",
    "..o#########-o..",
    "...o#######-o...",
    "....o#####-o....",
    ".....o###-o.....",
    "......o#-o......",
    ".......oo.......",
    "................",
    "................",
]
add("heart", "#e8404a", HEART)
add("intent_help", "#4ad870", HEART)

# ============================================================================ hands
# an open hand, palm towards you: four fingers with a clean gap between each, a thumb
# out to the side, a rounded heel
OPEN_HAND = [
    "................",
    ".......oo.......",
    "....ooo++ooo....",
    "...o+#o+#o+#o...",
    "...o+#o+#o+#ooo.",
    "...o+#o+#o+#o+#o",
    ".ooo+#o+#o+#o+#o",
    "o+#o+#o+#o+#o+#o",
    "o+#o+#########-o",
    "o+#+##########-o",
    ".o+###########-o",
    "..o+##########-o",
    "...o+#########-o",
    "...o+########-o.",
    "....o--------o..",
    ".....oooooooo...",
]
add("intent_disarm", "#5ab8f0", OPEN_HAND)

# a fist from the front: four knuckles, the thumb folded across them with its nail
FIST = [
    "................",
    "................",
    "...oo.oo.oo.oo..",
    "..o++o++o++o++o.",
    "..o+#o+#o+#o+#o.",
    "..o+#o+#o+#o+-o.",
    "..o-#o-#o-#o--o.",
    "..o++++++++o#-o.",
    "..o+######wo#-o.",
    "..o-------oo#-o.",
    "..o+#########-o.",
    "..o+########-o..",
    "...o+######-o...",
    "...o+######-o...",
    "...o--------o...",
    "....oooooooo....",
]
add("intent_harm", "#f04a3a", FIST)

# grabbing: a fist closed round a steel bar, the fingers wrapped over it and the thumb
# locked underneath
GRAB = [
    "................",
    "................",
    "....oooooooo....",
    "...o+#+#+#+#o...",
    "...o+#+#+#+#o...",
    "...o+#+#+#+#o...",
    "oooo+#+#+#+#oooo",
    "rrro+#+#+#+#orrr",
    "RRRo+#+#+#+#oRRR",
    "ssso-=-=-=-=osss",
    "oooo++++++w#oooo",
    "...o-------=o...",
    "...o+######-o...",
    "...o+######-o...",
    "....o------o....",
    ".....oooooo.....",
]
add("intent_grab", "#f0c030", GRAB, r="#dce4ee", R="#9aa4b4", s="#5a6272")

# ============================================================================ vitals
BOLT = [
    "................",
    ".......ooooo....",
    "......o+w##o....",
    ".....o+###o.....",
    "....o+###o......",
    "...o+###ooooo...",
    "..o+#########o..",
    "..oooooo###-o...",
    "......o###-o....",
    ".....o###-o.....",
    "....o##-o.......",
    "...o#-o.........",
    "..o-o...........",
    "..oo............",
    "................",
    "................",
]
add("stamina", "#ffcc30", BOLT)

THERMO = [
    "......oooo......",
    ".....owggGo.....",
    ".....ogggGo.....",
    ".....og+#Go.....",
    ".....og+#Go.....",
    ".....og+#Go.....",
    ".....og+#Go.....",
    ".....og+#Go.....",
    ".....og+#Go.....",
    "....oog+#Goo....",
    "...o+w####--o...",
    "...o+#####--o...",
    "...o+#####--o...",
    "....o-----=o....",
    ".....oooooo.....",
    "................",
]
add("temp", "#e8483a", THERMO, g="#c8d8e8", G="#7a8ea4")

DROP = [
    "................",
    ".......oo.......",
    "......o+#o......",
    "......o+#o......",
    ".....o++#-o.....",
    ".....o+##-o.....",
    "....o+w##--o....",
    "...o+w####--o...",
    "...o+#####--o...",
    "..o+#######--o..",
    "..o+#######--o..",
    "..o########--o..",
    "...o######--o...",
    "....o-----=o....",
    ".....oooooo.....",
    "................",
]
add("water", "#3aa8f8", DROP)

DRUMSTICK = [
    "................",
    "........oooo....",
    "......oo+++#oo..",
    ".....o+w+####-o.",
    ".....o++#####-o.",
    "....o++######-o.",
    "....o+#######-o.",
    "....o#######--o.",
    "....o######--o..",
    "....o-####--oo..",
    "...obo----oo....",
    "..obBo..........",
    ".obBo...........",
    "obbBo...........",
    "obBBo...........",
    ".ooo............",
]
add("food", "#d07a38", DRUMSTICK, b="#f4ecd8", B="#b8ae96")

# a crescent moon: a pixel disc with a disc cut out of its upper right
moon = disc(7.5, 8.0, 6.6) & ~disc(10.6, 5.6, 5.4)
add("energy", "#b89aff", shade_mask(moon, glint=[(3, 8)]))

# a brain, side on: two lobes, a stem, the folds drawn in the shade colour
BRAIN = [
    "................",
    "................",
    "....oooo.ooo....",
    "..oo+++#o+##oo..",
    ".o++#-##o##-##o.",
    ".o+#-#####-###o.",
    "o+##-###-####-#o",
    "o+#####-###-##-o",
    "o+#-####-#####-o",
    "o+##-###-###-#-o",
    ".o+###-###-##-o.",
    "..o-###-####-o..",
    "...o--o---=-o...",
    "......o=-o.oo...",
    ".......ooo......",
    "................",
]
add("stress", "#ff7aa0", BRAIN)

# ============================================================================ menu
STAR = [
    "................",
    ".......oo.......",
    "......o+#o......",
    "......o+#o......",
    ".....o++##o.....",
    "ooooo+w+##-ooooo",
    "o+++++++####--=o",
    ".o++#########-o.",
    "..o+########-o..",
    "...o+######-o...",
    "...o+######-o...",
    "..o+##-oo-##-o..",
    "..o+#-o..o-#-o..",
    ".o+-oo....oo--o.",
    ".oooo......oooo.",
    "................",
]
add("skills", "#ffc830", STAR)


# ============================================================================ menu bar
# a folded paper map, three panels catching the light differently, a red pin in it
MAP = [
    "................",
    "oooooo.....ooooo",
    "o+++++ooooo####o",
    "o+++++-----####o",
    "o+++++-rwr-####o",
    "o+++++-rrR-####o",
    "o+++++--R--####o",
    "o+++++--d--####o",
    "o+d+++-d---#d##o",
    "o++d+d-----##d#o",
    "o+++++-----####o",
    "oooooo-----ooooo",
    "......ooooo.....",
    "................",
    "................",
    "................",
]
add("map", "#a8d0ec", MAP, r="#f04a3a", R="#a82a22", d="#f04a3a")

# a claw hammer: steel head across the top, a wooden handle going down to the left
hammer_head = np.zeros((16, 16), bool)
hammer_handle = np.zeros((16, 16), bool)
for y in range(16):
    for x in range(16):
        u, v = x - y, x + y  # u runs along the head, v along the handle
        if 2.5 <= u <= 5.5 and 8 <= v <= 22:
            hammer_head[y, x] = True
        if abs(v - 15) <= 1 and -11 <= u <= 2:
            hammer_handle[y, x] = True
craft = shade_mask(hammer_head | hammer_handle, glint=[(8, 4)])
craft = ["".join(("h" if c in "+#" else "H") if hammer_handle[y, x] and not hammer_head[y, x] and c in "+#-" else c
                 for x, c in enumerate(row)) for y, row in enumerate(craft)]
add("craft", "#c8d4e0", craft, h="#c88a50", H="#8a5a30")

# ============================================================================ hand actions
# throw: a ball flying up and to the right, speed lines trailing it
ball = disc(10.5, 5.5, 3.6)
throw = shade_mask(ball, glint=[(9, 3)])
throw = put(throw, [(2, 12), (3, 12), (4, 12), (5, 11), (3, 9), (4, 9), (5, 9), (6, 8), (6, 14), (7, 13), (8, 12), (8, 11)], "s")
add("throw", "#ffb040", throw, s="#8ab0cc")

# resist: a chain snapping - two links pulled apart, sparks where it broke
link_a = (disc(4.5, 11.5, 3.7) & ~disc(4.5, 11.5, 1.7))
link_b = (disc(11.5, 4.5, 3.7) & ~disc(11.5, 4.5, 1.7))
# open each link on the side facing the break
for (x, y) in ((6, 9), (7, 9), (7, 10), (6, 8), (8, 9)):
    link_a[y, x] = False
for (x, y) in ((9, 6), (8, 6), (8, 5), (9, 7), (7, 6)):
    link_b[y, x] = False
resist = shade_mask(link_a | link_b)
resist = put(resist, [(8, 8), (7, 7), (9, 9), (10, 8), (6, 6), (9, 10)], "y")
add("resist", "#c8d0dc", resist, y="#ffd84a")

# internals: an oxygen tank, white stencil band, valve and gauge on top
TANK = [
    "......oooo......",
    "......o*:o......",
    ".....oo*:oo.....",
    "....o+####-o....",
    "...o++#####-o...",
    "...o+w#####-o...",
    "...o********o...",
    "...o::::::::o...",
    "...o+######-o...",
    "...o+######-o...",
    "...o+######-o...",
    "...o+######-o...",
    "...o-######=o...",
    "....o------o....",
    ".....oooooo.....",
    "................",
]
add("internals", "#3a78e0", TANK)

# pull: two chain links, joined
pl_a = disc(5.5, 8.5, 3.9) & ~disc(5.5, 8.5, 1.9)
pl_b = disc(10.5, 8.5, 3.9) & ~disc(10.5, 8.5, 1.9)
add("pull", "#c8d0dc", shade_mask(pl_a | pl_b))

# auto-resist: two arrows chasing each other round a circle
ring = disc(8, 8, 6.2) & ~disc(8, 8, 3.9)
for (x, y) in ((8, 1), (8, 2), (7, 13), (7, 14), (7, 12), (8, 3)):
    ring[y, x] = False
auto = shade_mask(ring)
auto = put(auto, [(9, 0), (10, 1), (9, 2), (10, 3), (6, 15), (5, 14), (6, 13), (5, 12)], "#")
add("auto", "#7fd4ff", auto)

# ============================================================================ movement
WALK = [
    ".......oo.......",
    "......o+#o......",
    "......o#-o......",
    ".....oooooo.....",
    "....o+####-o....",
    "....o+####-o....",
    "....o+####-o....",
    "....o+o##o-o....",
    ".....oo##oo.....",
    "......o+-o......",
    ".....o+oo-o.....",
    "....o+o..o-o....",
    "....o-o..o-o....",
    "...o+-o..o+-o...",
    "...oooo..oooo...",
    "................",
]
add("walk", "#d6e6f2", WALK)

RUN = [
    ".........oo.....",
    "........o+#o....",
    "........o#-o....",
    "...oo..oooo.....",
    "..o+#oo+##-o....",
    "...oo+####o+o...",
    ".....o+###oo-o..",
    ".....o+##-o.oo..",
    "......o+#-o.....",
    ".....o+#o-o.....",
    "....o+#o.o-oo...",
    "...o+#o...o+-o..",
    "..o+#o.....o-o..",
    "..o-o.......oo..",
    "..oo............",
    "................",
]
add("run", "#ffc84a", RUN)

SNEAK = [
    "................",
    "................",
    "........oo......",
    ".......o+#o.....",
    ".......o#-o.....",
    "....ooooooo.....",
    "...o+#####-o....",
    "..o+o+###-o-o...",
    "..oo.o+##-oo-o..",
    ".....o+###-oo...",
    "....o+#oo+-o....",
    "...o+#o.o+#o....",
    "...o-o..o+-o....",
    "..o+-o..o-o.....",
    "..oooo..ooo.....",
    "................",
]
add("sneak", "#a898e8", SNEAK)


def write():
    out = ["# Generated by icons_src/build_v2.py - edit that file, not this one.", ""]
    for name, col, extra, rows in ICONS:
        hdr = "@%s %s" % (name, col) + "".join(" %s=%s" % kv for kv in extra.items())
        out.append(hdr)
        out += rows
    path = os.path.join(os.path.dirname(__file__), "..", "ui_icons_v2.txt")
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("wrote %d icons" % len(ICONS))


if __name__ == "__main__":
    write()
