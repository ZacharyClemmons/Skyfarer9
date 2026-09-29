"""Status alert icons (tg /atom/movable/screen/alert): one distinct pictogram per alert, drawn
on a transparent 32x32 with a dark outline. The HUD tile around it shows the severity, so the
glyph only has to say *what* it is: no two alerts share a silhouette."""
import math

import numpy as np

from common import Canvas, ellipse_mask, hexc, rrect_mask, sel_outline, shade

W = hexc("#eef3f8")
DARK = hexc("#0d1118")


def _poly(cv, pts, col):
    from PIL import Image, ImageDraw
    im = Image.new("L", (32, 32), 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    cv.mask_fill(np.array(im).astype(bool), col)


def _thick(cv, x0, y0, x1, y1, col, w=2):
    for dx in range(w):
        for dy in range(w):
            cv.line(x0 + dx, y0 + dy, x1 + dx, y1 + dy, col)


def _arrow(cv, x0, y0, x1, y1, col):
    """A 2px arrow from (x0,y0) pointing at (x1,y1)."""
    _thick(cv, x0, y0, x1, y1, col)
    a = math.atan2(y1 - y0, x1 - x0)
    for s in (-1, 1):
        b = a + math.pi + s * 0.7
        _thick(cv, x1, y1, int(round(x1 + math.cos(b) * 4)), int(round(y1 + math.sin(b) * 4)), col)


def _person(cv, col, cx=16):
    cv.mask_fill(ellipse_mask(32, 32, cx, 11, 3, 3), col)
    cv.mask_fill(rrect_mask(32, 32, cx - 3, 15, cx + 3, 22, 1), col)


def _lungs(cv, col):
    for s in (-1, 1):
        cv.mask_fill(ellipse_mask(32, 32, 16 + s * 5, 18, 4.5, 7), col)
    cv.vline(16, 6, 14, col)
    cv.vline(15, 6, 14, col)
    cv.line(15, 13, 12, 15, col)
    cv.line(16, 13, 19, 15, col)


def _flame(cv, col, core, cx=16, top=5, bot=27, w=8):
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top)
        hw = int(round(math.sin(t * math.pi * 0.85 + 0.15) * w * (0.35 + 0.65 * t)))
        wob = int(round(math.sin(y * 0.9) * 1.2 * (1 - t)))
        cv.hline(cx - hw + wob, cx + hw + wob, y, col)
    cv.mask_fill(ellipse_mask(32, 32, cx, bot - 5, w * 0.4, 4), core)


def _zzz(cv, col, x=9, y=20):
    for i, s in enumerate((5, 4, 3)):
        ox, oy = x + i * 6, y - i * 6
        cv.hline(ox, ox + s, oy, col)
        cv.line(ox + s, oy, ox, oy + s, col)
        cv.hline(ox, ox + s, oy + s, col)


def _drop(cv, col, cx=16, top=6, bot=26, w=7):
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top)
        hw = int(round((math.sin(min(1.0, t * 1.25) * math.pi * 0.5) if t < 0.8 else math.cos((t - 0.8) / 0.2 * math.pi * 0.5)) * w))
        cv.hline(cx - hw, cx + hw, y, col)


def _cloud(cv, col, cy=17):
    for (x, y, r) in ((11, cy + 1, 5), (17, cy - 3, 6), (22, cy + 1, 5), (16, cy + 3, 6)):
        cv.mask_fill(ellipse_mask(32, 32, x, y, r, r * 0.85), col)


def _text(cv, s, x, y, col):
    """Tiny 3x5 pixel font for the few letters the icons need."""
    font = {
        "C": ["111", "100", "100", "100", "111"], "O": ["111", "101", "101", "101", "111"],
        "2": ["111", "001", "111", "100", "111"], "N": ["101", "111", "111", "101", "101"],
        "P": ["111", "101", "111", "100", "100"], "!": ["010", "010", "010", "000", "010"],
    }
    for ch in s:
        g = font[ch]
        for yy, row in enumerate(g):
            for xx, b in enumerate(row):
                if b == "1":
                    cv.rect(x + xx * 2, y + yy * 2, x + xx * 2 + 1, y + yy * 2 + 1, col)
        x += 8


def icon(k):
    cv = Canvas()
    if k == "oxy":  # lungs gasping: pale blue lungs, red X
        _lungs(cv, hexc("#7ab8ff"))
        _thick(cv, 20, 4, 27, 11, hexc("#ff4a4a"))
        _thick(cv, 27, 4, 20, 11, hexc("#ff4a4a"))
    elif k == "co2":  # a grey cloud marked CO2
        _cloud(cv, hexc("#8a93a3"))
        _text(cv, "CO2", 5, 13, W)
    elif k == "plasma":  # violet cloud with a skull-ish warning
        _cloud(cv, hexc("#b04ae8"))
        cv.mask_fill(ellipse_mask(32, 32, 16, 15, 4.5, 4), W)
        cv.rect(14, 18, 18, 21, W)
        for x in (14, 18):
            cv.mask_fill(ellipse_mask(32, 32, x, 15, 1.2, 1.2), hexc("#b04ae8"))
    elif k == "n2o":  # pale cloud, zzz
        _cloud(cv, hexc("#f0dcc0"))
        _zzz(cv, hexc("#5a4a3a"), 8, 21)
    elif k == "smoke":  # dark billowing cloud
        _cloud(cv, hexc("#4a4d55"), 19)
        for (x, y, r) in ((13, 9, 3), (19, 7, 2.5)):
            cv.mask_fill(ellipse_mask(32, 32, x, y, r, r), hexc("#6a6e78"))
    elif k == "cold":  # snowflake
        col = hexc("#8adcff")
        for a in range(0, 180, 60):
            dx, dy = math.cos(math.radians(a)) * 11, math.sin(math.radians(a)) * 11
            _thick(cv, int(16 - dx), int(16 - dy), int(16 + dx), int(16 + dy), col)
            for s in (-1, 1):
                ex, ey = 16 + dx * 0.6 * s, 16 + dy * 0.6 * s
                for b in (-0.8, 0.8):
                    ang = math.radians(a) + (0 if s > 0 else math.pi) + b
                    cv.line(int(ex), int(ey), int(ex + math.cos(ang) * 4), int(ey + math.sin(ang) * 4), col)
    elif k == "hot":  # thermometer, red to the top
        cv.mask_fill(rrect_mask(32, 32, 13, 4, 19, 22, 3), W)
        cv.mask_fill(ellipse_mask(32, 32, 16, 23, 5, 5), W)
        cv.mask_fill(rrect_mask(32, 32, 15, 6, 17, 22, 1), hexc("#ff4a2a"))
        cv.mask_fill(ellipse_mask(32, 32, 16, 23, 3.5, 3.5), hexc("#ff4a2a"))
        for y in (8, 12, 16):
            cv.hline(20, 22, y, hexc("#ff9a6a"))
    elif k == "fire":  # a person-high flame
        _flame(cv, hexc("#ff6a1a"), hexc("#ffe07a"))
    elif k == "lowpressure":  # a person, arrows pulling outward
        _person(cv, W)
        for (x0, y0, x1, y1) in ((9, 17, 3, 17), (23, 17, 29, 17), (16, 6, 16, 1), (11, 25, 6, 29), (21, 25, 26, 29)):
            _arrow(cv, x0, y0, x1, y1, hexc("#b8a8ff"))
    elif k == "highpressure":  # a person, arrows crushing inward
        _person(cv, W)
        for (x0, y0, x1, y1) in ((2, 17, 8, 17), (29, 17, 23, 17), (4, 4, 9, 9), (27, 4, 22, 9)):
            _arrow(cv, x0, y0, x1, y1, hexc("#ff5ad8"))
    elif k == "cuffed":  # handcuffs
        col = hexc("#c8d0dc")
        for cx in (10, 22):
            for a in range(0, 360, 6):
                for r in (5, 6):
                    cv.px(int(round(cx + math.cos(math.radians(a)) * r)), int(round(19 + math.sin(math.radians(a)) * r)), col)
        cv.hline(15, 17, 12, col)
        cv.line(12, 13, 15, 12, col)
        cv.line(17, 12, 20, 13, col)
    elif k == "buckled":  # a seat belt buckle
        col = hexc("#c8d0dc")
        cv.mask_fill(rrect_mask(32, 32, 3, 13, 12, 19, 0), hexc("#5a7ab8"))
        cv.mask_fill(rrect_mask(32, 32, 20, 13, 29, 19, 0), hexc("#5a7ab8"))
        m = rrect_mask(32, 32, 10, 10, 22, 22, 2) & ~rrect_mask(32, 32, 13, 13, 19, 19, 1)
        cv.mask_fill(m, col)
        cv.rect(15, 11, 17, 21, col)
    elif k == "bleeding":  # a drop of blood and two drips
        _drop(cv, hexc("#e0283a"), 14, 5, 25, 7)
        cv.mask_fill(ellipse_mask(32, 32, 24, 24, 2, 2.5), hexc("#e0283a"))
        cv.mask_fill(ellipse_mask(32, 32, 24, 17, 1.2, 1.5), hexc("#e0283a"))
        cv.px(11, 12, hexc("#ff8a8a"))
        cv.px(11, 13, hexc("#ff8a8a"))
    elif k == "pain":  # a jagged starburst
        pts = []
        for i in range(16):
            r = 13 if i % 2 == 0 else 6
            a = i / 16 * math.tau + 0.2
            pts.append((16 + math.cos(a) * r, 16 + math.sin(a) * r))
        _poly(cv, pts, hexc("#ffb03a"))
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 3.5, 3.5), hexc("#fff0c0"))
    elif k == "sick":  # a virus: body and spikes
        col = hexc("#8ad84a")
        for i in range(8):
            a = i / 8 * math.tau
            cv.line(16, 16, int(16 + math.cos(a) * 12), int(16 + math.sin(a) * 12), col)
            cv.mask_fill(ellipse_mask(32, 32, 16 + math.cos(a) * 12, 16 + math.sin(a) * 12, 1.6, 1.6), col)
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 7, 7), col)
        for (x, y) in ((14, 14), (18, 17), (15, 19)):
            cv.mask_fill(ellipse_mask(32, 32, x, y, 1.3, 1.3), shade(col, -0.35))
    elif k in ("hungry", "starving"):  # a bowl and spoon; starving: empty and cracked
        bowl = hexc("#e8a83a") if k == "hungry" else hexc("#b0643a")
        m = ellipse_mask(32, 32, 16, 17, 11, 9) & ~ellipse_mask(32, 32, 16, 10, 12, 6)
        cv.mask_fill(m, bowl)
        cv.hline(8, 24, 17, shade(bowl, 0.3))
        if k == "hungry":
            cv.mask_fill(ellipse_mask(32, 32, 16, 15, 8, 2), hexc("#f0e0b0"))
        else:
            cv.line(17, 18, 15, 22, DARK)
            cv.line(15, 22, 17, 25, DARK)
        _thick(cv, 22, 3, 26, 12, hexc("#c8d0dc"), 1)
        cv.mask_fill(ellipse_mask(32, 32, 21.5, 3, 2, 2.5), hexc("#c8d0dc"))
    elif k == "thirsty":  # a water drop
        _drop(cv, hexc("#4ab8ff"))
        cv.px(13, 14, W)
        cv.px(13, 15, W)
    elif k == "tired":  # a crescent moon and z
        moon = ellipse_mask(32, 32, 13, 17, 9, 9) & ~ellipse_mask(32, 32, 17, 14, 8, 8)
        cv.mask_fill(moon, hexc("#c8b8ff"))
        _zzz(cv, hexc("#c8b8ff"), 18, 14)
    elif k == "winded":  # a runner with sweat drops
        col = hexc("#ffd84a")
        cv.mask_fill(ellipse_mask(32, 32, 18, 7, 3, 3), col)
        _thick(cv, 17, 10, 14, 19, col)
        _thick(cv, 14, 19, 19, 26, col)
        _thick(cv, 14, 19, 9, 25, col)
        _thick(cv, 16, 13, 22, 16, col)
        _thick(cv, 16, 13, 10, 13, col)
        for (x, y) in ((24, 6), (26, 10)):
            _drop(cv, hexc("#6ac8ff"), x, y, y + 4, 1)
    elif k == "stunned":  # circling stars over a head
        cv.mask_fill(ellipse_mask(32, 32, 16, 22, 6, 6), W)
        for i in range(3):
            a = i / 3 * math.tau + 0.4
            x, y = 16 + math.cos(a) * 10, 9 + math.sin(a) * 4
            for s in range(4):
                b = s / 4 * math.tau
                cv.line(int(x), int(y), int(round(x + math.cos(b) * 2.5)), int(round(y + math.sin(b) * 2.5)), hexc("#ffe04a"))
    elif k == "floored":  # a person lying flat
        col = W
        cv.mask_fill(ellipse_mask(32, 32, 7, 20, 3, 3), col)
        cv.mask_fill(rrect_mask(32, 32, 10, 18, 26, 22, 1), col)
        cv.hline(3, 29, 25, hexc("#8a93a3"))
        _arrow(cv, 20, 4, 20, 13, hexc("#ffb03a"))
    elif k == "unconscious":  # a closed eye
        col = W
        for x in range(6, 27):
            y = int(round(15 + math.sin((x - 6) / 20 * math.pi) * 4))
            cv.px(x, y, col)
            cv.px(x, y + 1, col)
        for x in (9, 13, 19, 23):
            y = int(round(15 + math.sin((x - 6) / 20 * math.pi) * 4))
            cv.line(x, y + 2, x - (1 if x < 16 else -1), y + 5, col)
        _zzz(cv, hexc("#9ab8ff"), 20, 8)
    elif k == "internals":  # an air tank with a gauge
        cv.mask_fill(rrect_mask(32, 32, 11, 8, 21, 28, 4), hexc("#4a8ad8"))
        cv.rect(14, 4, 18, 7, hexc("#c8d0dc"))
        cv.mask_fill(ellipse_mask(32, 32, 16, 17, 3.5, 3.5), W)
        cv.line(16, 17, 18, 15, DARK)
    elif k == "blurry":  # an eye with doubled outline
        for off, col in ((2, hexc("#8a93a3")), (0, W)):
            for x in range(5, 28):
                t = (x - 5) / 22
                h = int(round(math.sin(t * math.pi) * 7))
                cv.px(x + off, 16 - h, col)
                cv.px(x + off, 16 + h, col)
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 4, 4), hexc("#6ab8e8"))
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 1.8, 1.8), DARK)
    elif k == "pulled":  # a hand grabbing
        col = hexc("#e8c8a8")
        cv.mask_fill(rrect_mask(32, 32, 9, 14, 23, 26, 3), col)
        for i, x in enumerate((10, 14, 18, 22)):
            cv.mask_fill(rrect_mask(32, 32, x - 1, 7 + (i % 2), x + 2, 15, 1), col)
        cv.mask_fill(rrect_mask(32, 32, 4, 16, 10, 20, 1), col)
    elif k == "determined":  # a clenched fist, sparks of adrenaline
        col = hexc("#ff8a4a")
        cv.mask_fill(rrect_mask(32, 32, 9, 12, 23, 26, 3), col)
        for x in (11, 15, 19):
            cv.vline(x, 13, 18, shade(col, -0.3))
        cv.mask_fill(rrect_mask(32, 32, 5, 16, 11, 21, 1), col)
        for (x, y) in ((7, 5), (16, 3), (25, 5)):
            _thick(cv, x, y, x, y + 4, hexc("#ffe04a"), 1)
    elif k == "limp":  # a leg with a crack and a cane
        col = W
        _thick(cv, 13, 4, 13, 18, col)
        _thick(cv, 13, 18, 16, 27, col)
        cv.hline(16, 20, 27, col)
        cv.line(11, 10, 15, 12, hexc("#ff4a4a"))
        cv.line(15, 12, 12, 14, hexc("#ff4a4a"))
        _thick(cv, 23, 8, 23, 28, hexc("#c89a5a"), 1)
        cv.hline(20, 23, 8, hexc("#c89a5a"))
    elif k == "asleep":  # a pillow and zzz
        cv.mask_fill(rrect_mask(32, 32, 4, 18, 28, 26, 4), W)
        _zzz(cv, hexc("#9ab8ff"), 10, 14)
    elif k == "paralyzed":  # a lying figure bound by bolts
        cv.mask_fill(ellipse_mask(32, 32, 7, 20, 3, 3), W)
        cv.mask_fill(rrect_mask(32, 32, 10, 18, 26, 22, 1), W)
        for x in (14, 20):
            _thick(cv, x, 8, x - 2, 14, hexc("#ffe04a"), 1)
            _thick(cv, x - 2, 14, x + 1, 14, hexc("#ffe04a"), 1)
            _thick(cv, x + 1, 14, x - 1, 17, hexc("#ffe04a"), 1)
    elif k == "immobilized":  # a figure with feet chained
        _person(cv, W)
        cv.hline(8, 24, 28, hexc("#8a93a3"))
        for x in (10, 14, 18, 22):
            cv.mask_fill(ellipse_mask(32, 32, x, 28, 1.6, 1.2), hexc("#c8d0dc"))
    elif k == "stamcrit":  # an empty stamina bar
        cv.mask_fill(rrect_mask(32, 32, 4, 11, 26, 21, 2), W)
        cv.mask_fill(rrect_mask(32, 32, 6, 13, 24, 19, 1), DARK)
        cv.rect(7, 14, 9, 18, hexc("#ff4a4a"))
        cv.rect(27, 14, 28, 18, W)
    elif k == "softcrit":  # a heart with a flat line
        heart = ellipse_mask(32, 32, 11, 12, 6, 6) | ellipse_mask(32, 32, 21, 12, 6, 6)
        cv.mask_fill(heart, hexc("#e0283a"))
        _poly(cv, [(5, 14), (27, 14), (16, 28)], hexc("#e0283a"))
        cv.hline(3, 11, 17, W)
        cv.line(11, 17, 13, 12, W)
        cv.line(13, 12, 15, 21, W)
        cv.line(15, 21, 17, 17, W)
        cv.hline(17, 29, 17, W)
    elif k == "blind":  # an eye struck through
        for x in range(5, 28):
            t = (x - 5) / 22
            h = int(round(math.sin(t * math.pi) * 7))
            cv.px(x, 16 - h, W)
            cv.px(x, 16 + h, W)
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 4, 4), hexc("#6a7486"))
        _thick(cv, 6, 26, 26, 6, hexc("#ff4a4a"))
    elif k == "high":  # a swirl of colours
        for i in range(40):
            a = i / 40 * math.tau * 2
            r = 2 + i * 0.3
            c = [hexc("#ff4ad8"), hexc("#4ae8ff"), hexc("#e8ff4a")][i % 3]
            cv.mask_fill(ellipse_mask(32, 32, 16 + math.cos(a) * r, 16 + math.sin(a) * r, 1.3, 1.3), c)
    elif k == "drunk":  # a tipped bottle, spilling
        m = np.zeros((32, 32), bool)
        for t in range(18):
            x, y = 8 + t * 0.8, 24 - t * 0.8
            m |= ellipse_mask(32, 32, x, y, 3.2, 3.2)
        cv.mask_fill(m, hexc("#3a8a4a"))
        _thick(cv, 22, 10, 26, 6, hexc("#2a6a3a"))
        for i, (x, y) in enumerate([(27, 9), (28, 13), (26, 17)]):
            cv.mask_fill(ellipse_mask(32, 32, x, y, 1.2, 1.6), hexc("#e8d88a"))
    elif k == "disgust":  # a queasy green face
        cv.mask_fill(ellipse_mask(32, 32, 16, 16, 11, 11), hexc("#8ac85a"))
        cv.mask_fill(ellipse_mask(32, 32, 12, 13, 1.5, 1.5), DARK)
        cv.mask_fill(ellipse_mask(32, 32, 20, 13, 1.5, 1.5), DARK)
        for x in range(10, 23):
            cv.px(x, 21 + (1 if (x // 2) % 2 else 0), DARK)
    elif k == "embedded":  # a blade stuck in flesh
        cv.mask_fill(ellipse_mask(32, 32, 16, 20, 10, 6), hexc("#e8b89a"))
        _thick(cv, 10, 6, 17, 19, hexc("#c8d0dc"), 3)
        _thick(cv, 8, 4, 11, 7, hexc("#6a5030"), 3)
        for x, y in [(18, 21), (15, 23), (20, 24)]:
            cv.mask_fill(ellipse_mask(32, 32, x, y, 1.3, 1.6), hexc("#b82020"))
    elif k == "trance":  # a spiral
        for i in range(60):
            a = i / 60 * math.tau * 3
            r = 1 + i * 0.2
            cv.mask_fill(ellipse_mask(32, 32, 16 + math.cos(a) * r, 16 + math.sin(a) * r, 1.0, 1.0), hexc("#c8a8ff"))
    elif k == "deaf":  # an ear struck through
        m = ellipse_mask(32, 32, 16, 15, 7, 10) & ~ellipse_mask(32, 32, 17, 15, 4, 7)
        cv.mask_fill(m, hexc("#e8c8a8"))
        cv.mask_fill(ellipse_mask(32, 32, 15, 24, 3, 2), hexc("#e8c8a8"))
        _thick(cv, 6, 26, 26, 6, hexc("#ff4a4a"))
    sel_outline(cv, color=DARK)
    return cv


ALERTS = ["oxy", "co2", "plasma", "n2o", "smoke", "cold", "hot", "fire", "lowpressure", "highpressure",
          "cuffed", "buckled", "bleeding", "pain", "sick", "hungry", "starving", "thirsty", "tired", "winded",
          "stunned", "floored", "unconscious", "internals", "blurry", "pulled", "determined", "limp", "asleep",
          "paralyzed", "immobilized", "stamcrit", "softcrit", "blind", "high", "deaf", "drunk", "disgust", "trance", "embedded"]
