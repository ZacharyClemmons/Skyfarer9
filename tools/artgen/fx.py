"""Effects (fire, smoke, sparks, snow, explosions, light textures) and HUD icons."""
import math

import numpy as np

from common import (Canvas, ellipse_mask, fbm, hexc, mix, ramp, rng_for,
                    rrect_mask, sel_outline, shade, shaded_fill, value_noise)
from objects import Packer

FIRE = [hexc(h) for h in ("#5a0a0a", "#a8200a", "#e8500a", "#ff9a1a", "#ffd84a", "#fff8c8")]


def fire_frame(intensity, frame):
    """intensity 0..2, frame 0..3. Flame tongues rising from the tile floor."""
    cv = Canvas()
    rng = rng_for(f"fire{intensity}{frame}")
    n = fbm(32, 64, 100 + intensity * 7, 3, 8)
    h = [14, 22, 30][intensity]
    width = [9, 12, 15][intensity]
    for y in range(32):
        for x in range(32):
            fy = 31 - y  # height above floor
            if fy > h:
                continue
            ny = (y + frame * 5) % 64
            turb = (n[ny, x] - 0.5) * 7
            cx = 16 + math.sin(fy * 0.35 + frame * 1.6) * 2 + turb * 0.4
            w = width * (1 - (fy / h) ** 1.3) + turb * 0.6
            d = abs(x + 0.5 - cx)
            if d < w:
                t = 1 - d / max(w, 0.1)
                heat = t * 0.9 + (1 - fy / h) * 0.5 + (n[ny, x] - 0.5) * 0.4
                idx = int(np.clip(heat * 4.2, 0, 5))
                if idx == 0 and rng.random() < 0.5:
                    continue
                cv.px(x, y, FIRE[idx])
    # embers
    for _ in range(3 + intensity * 2):
        x = rng.randint(6, 25)
        y = rng.randint(2, 31 - h // 2)
        cv.px(x, y, FIRE[4])
    return cv


def smoke(v, dense=False):
    cv = Canvas()
    rng = rng_for(f"smoke{v}{dense}")
    n = fbm(32, 32, 300 + v, 3, 8)
    base = hexc("#3a3a44") if dense else hexc("#8a8e9a")
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 16, y - 16) / 15
            a = (1 - d) * 0.9 + (n[y, x] - 0.5) * 0.9
            if a > 0.15:
                lit = (16 - y) / 32 * 0.4 + (n[y, x] - 0.5) * 0.3
                c = shade(base, lit)
                c[3] = min(0.85, a) * (0.9 if dense else 0.6)
                cv.px(x, y, c)
    return cv


def sparks(frame):
    cv = Canvas()
    rng = rng_for(f"spark{frame}")
    for _ in range(9):
        a = rng.uniform(0, 6.28)
        r = 3 + frame * 3 + rng.uniform(0, 3)
        ln = rng.randint(1, 3)
        for k in range(ln):
            x = int(16 + math.cos(a) * (r + k))
            y = int(16 + math.sin(a) * (r + k) + frame * frame * 0.6)
            cv.px(x, y, hexc("#fff8c8") if k == 0 else hexc("#ffb84a"))
    return cv


def glass_frag(v):
    """A flying sliver of window glass for the shatter burst (tg: the pane bursts into shards)."""
    shapes = [
        ["..#....", ".###...", ".####..", "######.", ".#####.", "..###..", "...#..."],
        ["#......", "##.....", "###....", "####...", "#####..", "######."],
        ["...#", "..##", ".###", "####", "###.", "##..", "#..."],
        [".##.....", "#####...", ".######.", "..######", "....###."],
        ["..#..", ".###.", ".###.", "#####", ".###.", "..#.."],
        ["##.", "###", ".##"],
    ][v]
    h, w = len(shapes), len(shapes[0])
    cv = Canvas(w, h)
    body = hexc("#9fd0ec", 0.92)
    edge = hexc("#2f5a80", 1.0)
    hi = hexc("#ffffff", 1.0)
    for y, row in enumerate(shapes):
        for x, ch in enumerate(row):
            if ch == "#":
                cv.px(x, y, body)
    for y in range(h):
        for x in range(w):
            if cv.get(x, y)[3] > 0 and (cv.get(x + 1, y)[3] == 0 or cv.get(x, y + 1)[3] == 0):
                cv.px(x, y, edge)
    done = False
    for y in range(h):
        for x in range(w):
            if not done and cv.get(x, y)[3] > 0:
                cv.px(x, y, hi)
                done = True
    return cv


def glass_chip():
    """A tiny glint knocked off the pane by a hit."""
    cv = Canvas(3, 3)
    cv.px(1, 0, hexc("#b8e2f6", 0.8))
    cv.px(0, 1, hexc("#b8e2f6", 0.8))
    cv.px(1, 1, hexc("#ffffff"))
    cv.px(2, 1, hexc("#5d8db0", 0.9))
    cv.px(1, 2, hexc("#5d8db0", 0.9))
    return cv


def attack_effect(kind):
    """tg ATTACK_EFFECT_PUNCH / KICK / SMASH: the little impact mark drawn on what you hit."""
    cv = Canvas()
    rng = rng_for(f"atk{kind}")
    col = {"punch": "#fff2c8", "kick": "#ffe08a", "smash": "#ffffff"}[kind]
    core = hexc(col)
    rim = hexc("#ff9a3a" if kind != "smash" else "#9fd0ec", 0.85)
    rays = {"punch": 8, "kick": 10, "smash": 12}[kind]
    for k in range(rays):
        a = k / rays * 6.283 + rng.uniform(-0.15, 0.15)
        ln = rng.uniform(4, 7) if k % 2 == 0 else rng.uniform(2, 4)
        if kind == "kick":
            ln *= 1.25
        for i in range(int(ln) + 2):
            x = int(round(16 + math.cos(a) * (2 + i)))
            y = int(round(16 + math.sin(a) * (2 + i)))
            cv.px(x, y, core if i < ln * 0.6 else rim)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            cv.px(16 + dx, 16 + dy, core)
    return cv


def explosion(frame):
    cv = Canvas(64, 64)
    rng = rng_for(f"boom{frame}")
    n = fbm(64, 64, 900 + frame, 3, 16)
    r = 8 + frame * 5
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 32, y - 32) / r + (n[y, x] - 0.5) * 0.5
            if d < 1:
                t = 1 - d
                heat = t * 1.2 - frame * 0.12
                if heat < 0.15:
                    c = hexc("#3a3a44")
                    c[3] = 0.8
                else:
                    c = FIRE[int(np.clip(heat * 5.5, 0, 5))]
                cv.px(x, y, c)
    return cv


def light_tex(size=128, falloff=2.0):
    cv = Canvas(size, size)
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            a = max(0.0, 1 - d) ** falloff
            cv.a[y, x] = [1, 1, 1, a]
    return cv


def flake(size):
    cv = Canvas(8, 8)
    if size == 0:
        cv.px(3, 3, hexc("#ffffff"))
    elif size == 1:
        for (x, y) in ((3, 3), (4, 3), (3, 4), (4, 4)):
            cv.px(x, y, hexc("#ffffff"))
    else:
        for (x, y) in ((3, 2), (2, 3), (3, 3), (4, 3), (3, 4)):
            cv.px(x, y, hexc("#ffffff"))
        for (x, y) in ((2, 2), (4, 4), (4, 2), (2, 4)):
            cv.px(x, y, hexc("#ffffff", 0.45))
    return cv


def streak():
    cv = Canvas(32, 8)
    for x in range(32):
        a = math.sin(x / 31 * math.pi) * 0.7
        cv.px(x, 4, (1, 1, 1, a))
        cv.px(x, 3, (1, 1, 1, a * 0.3))
    return cv


def breath_puff():
    cv = Canvas(16, 16)
    n = value_noise(16, 16, 4, 5)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 8, y - 8) / 7
            a = (1 - d) * 0.8 + (n[y, x] - 0.5) * 0.5
            if a > 0.1:
                cv.a[y, x] = [1, 1, 1, min(0.9, a)]
    return cv


def gas_cloud(v):
    """Tileable soft gas texture; tinted per gas in engine."""
    cv = Canvas()
    n = fbm(32, 32, 1200 + v, 4, 16)
    for y in range(32):
        for x in range(32):
            a = np.clip((n[y, x] - 0.3) * 1.6, 0, 1)
            cv.a[y, x] = [1, 1, 1, a]
    return cv


def foam():
    cv = Canvas()
    rng = rng_for("foam")
    for _ in range(40):
        x, y = rng.randint(2, 29), rng.randint(2, 29)
        r = rng.uniform(1, 3)
        m = ellipse_mask(32, 32, x, y, r, r)
        ys, xs = np.nonzero(m)
        for yy, xx in zip(ys, xs):
            cv.px(xx, yy, hexc("#f4f8ff", 0.85))
        cv.px(x - 1, y - 1, hexc("#ffffff"))
    return cv


# ------------------------------------------------------------------ HUD icons
UI_BG = hexc("#1b2230")
UI_HI = hexc("#6fa8c8")


def glyph_canvas():
    return Canvas()


# ---- empty-slot ghosts: 16x16 shapes shaded like the hand, drawn at 2x
def _g_rect(x0, y0, x1, y1, round_=True):
    m = np.zeros((16, 16), bool)
    m[y0:y1 + 1, x0:x1 + 1] = True
    if round_:
        for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            m[y, x] = False
    return m


def _g_ell(cx, cy, rx, ry):
    yy, xx = np.mgrid[0:16, 0:16]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def _ghost(cv, m, g, g2):
    """Lit top/left edges, shaded bottom/right, flat middle; holes stay see-through."""
    lit, dark = mix(g2, g, 0.55), shade(g2, -0.25)
    for y in range(16):
        for x in range(16):
            if not m[y, x]:
                continue
            up = y == 0 or not m[y - 1, x]
            lf = x == 0 or not m[y, x - 1]
            dn = y == 15 or not m[y + 1, x]
            rt = x == 15 or not m[y, x + 1]
            c = lit if (up or lf) else (dark if (dn or rt) else g2)
            cv.rect(x * 2, y * 2, x * 2 + 1, y * 2 + 1, c)


def _gh_head():  # a hard hat with its brim
    m = _g_ell(8, 9, 5.5, 5.5) & _g_rect(0, 0, 15, 8, False)
    m |= _g_rect(1, 9, 14, 10)
    m &= ~_g_rect(7, 4, 8, 8, False)
    return m


def _gh_mask():  # a gas mask: two eyepieces and a filter
    m = _g_ell(8, 7.5, 6, 5.5)
    m |= _g_ell(8, 12.5, 2.6, 2.6)
    for cx in (5.5, 10.5):
        m &= ~_g_ell(cx, 7, 1.7, 1.7)
    m &= ~_g_rect(7, 12, 8, 12, False)
    return m


def _gh_uniform():  # a jumpsuit
    m = _g_rect(4, 2, 11, 9) | _g_rect(1, 2, 4, 7) | _g_rect(11, 2, 14, 7)
    m |= _g_rect(4, 9, 7, 14) | _g_rect(8, 9, 11, 14)
    m &= ~_g_rect(6, 2, 9, 3, False)
    m &= ~_g_rect(7, 11, 8, 14, False)
    return m


def _gh_suit():  # a long coat, open collar
    m = _g_rect(3, 2, 12, 14) | _g_rect(0, 3, 3, 11) | _g_rect(12, 3, 15, 11)
    m &= ~_g_rect(6, 2, 9, 5, False)
    m[6:15, 7] = False
    return m


def _gh_gloves():
    m = _g_rect(4, 7, 11, 13) | _g_rect(4, 3, 5, 8) | _g_rect(6, 2, 7, 8) | _g_rect(8, 2, 9, 8) | _g_rect(10, 3, 11, 8)
    m |= _g_rect(11, 7, 13, 10)
    m[3:8, 6] = False
    m[3:8, 8] = False
    m[4:8, 10] = False
    return m


def _gh_shoes():  # a pair of boots
    m = _g_rect(2, 4, 5, 12) | _g_rect(2, 10, 7, 13) | _g_rect(9, 4, 12, 12) | _g_rect(9, 10, 14, 13)
    return m


def _gh_back():  # a backpack with a flap and pocket
    m = _g_rect(3, 3, 12, 14) | _g_rect(6, 1, 9, 3)
    m &= ~_g_rect(7, 2, 8, 2, False)
    m[7, 4:12] = False
    m &= ~_g_rect(6, 10, 9, 12, False)
    return m


def _gh_belt():
    m = _g_rect(0, 6, 15, 9, False)
    m &= ~_g_rect(6, 6, 9, 9, False)
    m |= _g_rect(6, 5, 9, 10) & ~_g_rect(7, 7, 8, 8, False)
    return m


def _gh_id():  # an ID card: photo and text lines
    m = _g_rect(1, 3, 14, 12)
    m &= ~_g_rect(3, 5, 6, 10, False)
    m[6, 8:13] = False
    m[9, 8:12] = False
    return m


def _gh_ears():  # a headset
    m = _g_ell(8, 9, 6.5, 6.5) & ~_g_ell(8, 9, 5, 5) & _g_rect(0, 0, 15, 9, False)
    m |= _g_rect(1, 8, 4, 13) | _g_rect(11, 8, 14, 13)
    return m


def _gh_eyes():  # glasses
    m = _g_ell(4.5, 8, 3.5, 2.8) | _g_ell(11.5, 8, 3.5, 2.8) | _g_rect(7, 7, 8, 7, False)
    m &= ~_g_ell(4.5, 8, 2, 1.4)
    m &= ~_g_ell(11.5, 8, 2, 1.4)
    return m


def _gh_pocket():  # a jeans pocket: a shield shape with a curved opening across the top
    m = _g_rect(3, 2, 12, 9, False) | (_g_ell(7.5, 8.5, 5, 5.5) & _g_rect(0, 9, 15, 15, False))
    m[2, 3] = m[2, 12] = False
    # the opening: a dipping curve cut right across
    for x in range(3, 13):
        y = 4 + int(round(((x - 7.5) / 4.5) ** 2 * -1.6 + 1.6))
        m[y, x] = False
    # a rivet at each end of the opening
    m[3, 3] = m[3, 12] = False
    return m


GHOSTS = {"slot_head": _gh_head, "slot_mask": _gh_mask, "slot_uniform": _gh_uniform, "slot_suit": _gh_suit,
          "slot_gloves": _gh_gloves, "slot_shoes": _gh_shoes, "slot_back": _gh_back, "slot_belt": _gh_belt,
          "slot_id": _gh_id, "slot_ears": _gh_ears, "slot_eyes": _gh_eyes, "slot_pocket": _gh_pocket}


def icon(name):
    """HUD icons: pale glyphs meant to sit on the frosted slot panels drawn by Godot."""
    cv = Canvas()
    g = hexc("#cfe3f0")
    g2 = hexc("#7fa3bf")
    warn = hexc("#ffb84a")
    bad = hexc("#ff5a4a")
    if name in GHOSTS:
        _ghost(cv, GHOSTS[name](), g, g2)
    elif name == "hand_l" or name == "hand_r":
        # the same hand-drawn open hand as the disarm intent, as a soft silhouette at 2x
        import sys as _sys, os as _os
        _sys.path.insert(0, _os.path.join(_os.path.dirname(__file__), "icons_src"))
        from build_v2 import OPEN_HAND
        # the HUD is mirrored (tg: your character faces you), so the right hand sits on the
        # left of the screen: both thumbs point in towards the middle
        rows = OPEN_HAND if name == "hand_l" else [r[::-1] for r in OPEN_HAND]
        tone = {"+": mix(g2, g, 0.55), "#": g2, "-": shade(g2, -0.25), "=": shade(g2, -0.4), "w": mix(g2, g, 0.55)}
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in tone:
                    cv.rect(x * 2, y * 2, x * 2 + 1, y * 2 + 1, tone[ch])
    elif name == "act_drop":
        for i in range(8):
            cv.hline(16 - i, 16 + i, 20 + i // 2, g)
        cv.mask_fill(rrect_mask(32, 32, 14, 6, 17, 18, 0), g)
    elif name == "act_swap":
        for i in range(5):
            cv.vline(8 + i, 12 - i, 12 + i, g)
            cv.vline(23 - i, 20 - i, 20 + i, g)
        cv.hline(12, 22, 12, g)
        cv.hline(9, 19, 20, g)
    elif name == "act_throw":
        for i in range(10):
            cv.px(8 + i, 24 - i, g)
            cv.px(9 + i, 24 - i, g)
        cv.mask_fill(ellipse_mask(32, 32, 22, 11, 4, 4), warn)
    elif name == "act_pull":
        for a in range(0, 360, 10):
            cv.px(int(13 + math.cos(math.radians(a)) * 5), int(16 + math.sin(math.radians(a)) * 5), g)
            cv.px(int(20 + math.cos(math.radians(a)) * 5), int(16 + math.sin(math.radians(a)) * 5), g2)
    elif name == "act_resist":
        cv.mask_fill(rrect_mask(32, 32, 8, 10, 23, 22, 3), g2)
        for x in range(10, 23, 3):
            cv.vline(x, 12, 20, UI_BG)
    elif name == "act_internals":
        cv.mask_fill(rrect_mask(32, 32, 12, 7, 19, 26, 3), hexc("#3a6ad8"))
        cv.mask_fill(rrect_mask(32, 32, 14, 4, 17, 7, 0), g2)
    elif name == "act_combat":
        for i in range(12):
            cv.px(9 + i, 22 - i, g)
            cv.px(10 + i, 22 - i, g)
            cv.px(22 - i, 22 - i, g)
            cv.px(21 - i, 22 - i, g)
    elif name == "act_combat_on":
        for i in range(12):
            for c in ((9 + i, 22 - i), (10 + i, 22 - i), (22 - i, 22 - i), (21 - i, 22 - i)):
                cv.px(*c, bad)
    elif name == "act_walk":
        cv.mask_fill(ellipse_mask(32, 32, 16, 8, 3, 3), g)
        cv.mask_fill(rrect_mask(32, 32, 14, 12, 18, 20, 1), g)
        cv.line(15, 20, 12, 27, g)
        cv.line(17, 20, 20, 27, g)
    elif name == "act_run":
        cv.mask_fill(ellipse_mask(32, 32, 18, 8, 3, 3), warn)
        cv.mask_fill(rrect_mask(32, 32, 14, 12, 19, 19, 1), warn)
        cv.line(15, 19, 9, 24, warn)
        cv.line(18, 19, 23, 26, warn)
        cv.line(14, 13, 9, 17, warn)
    # alerts
    elif name.startswith("alert_"):
        k = name[6:]
        col = {"cold": hexc("#6ac8ff"), "hot": hexc("#ff7a3a"), "oxy": hexc("#6a9aff"), "tox": hexc("#8aff4a"),
               "hungry": warn, "starving": bad, "thirsty": hexc("#4ab8ff"), "fire": hexc("#ff6a1a"),
               "lowpressure": hexc("#b8a8ff"), "highpressure": hexc("#ff4ad8"), "cuffed": g, "tired": hexc("#b89aff"),
               "pain": bad, "bleeding": bad, "sick": hexc("#9ad84a")}[k]
        # badge
        m = rrect_mask(32, 32, 3, 3, 28, 28, 6)
        cv.mask_fill(m, mix(UI_BG, col, 0.25))
        ring = m & ~rrect_mask(32, 32, 5, 5, 26, 26, 5)
        cv.mask_fill(ring, col)
        if k == "cold":
            for a in range(0, 180, 30):
                dx, dy = math.cos(math.radians(a)) * 8, math.sin(math.radians(a)) * 8
                cv.line(int(16 - dx), int(16 - dy), int(16 + dx), int(16 + dy), col)
        elif k in ("hot", "fire"):
            for y in range(9, 24):
                w = int((y - 9) / 15 * 6)
                cv.hline(16 - w, 16 + w, y, col)
            cv.mask_fill(ellipse_mask(32, 32, 16, 20, 2.5, 3), hexc("#ffe07a"))
        elif k == "oxy":
            for a in range(0, 360, 8):
                cv.px(int(16 + math.cos(math.radians(a)) * 6), int(16 + math.sin(math.radians(a)) * 6), col)
            cv.mask_fill(rrect_mask(32, 32, 14, 13, 17, 19, 0), col)
        elif k == "tox":
            cv.mask_fill(ellipse_mask(32, 32, 16, 13, 6, 5), col)
            cv.mask_fill(rrect_mask(32, 32, 12, 16, 19, 21, 1), col)
            for x in (13, 18):
                cv.mask_fill(ellipse_mask(32, 32, x + 0.5, 13, 1.5, 1.5), UI_BG)
        elif k in ("hungry", "starving"):
            m2 = ellipse_mask(32, 32, 16, 17, 7, 6)
            cv.mask_fill(m2, col)
            cv.hline(10, 22, 13, UI_BG)
        elif k == "thirsty":
            for y in range(8, 24):
                w = int(math.sin((y - 8) / 16 * math.pi * 0.9) * 6)
                cv.hline(16 - w, 16 + w, y, col)
        elif k in ("lowpressure", "highpressure"):
            for i in range(3):
                cv.hline(9, 23, 10 + i * 5, col)
            cv.vline(16, 8, 24, col)
        elif k == "cuffed":
            for cx in (11, 21):
                for a in range(0, 360, 12):
                    cv.px(int(cx + math.cos(math.radians(a)) * 4), int(16 + math.sin(math.radians(a)) * 4), col)
            cv.hline(15, 17, 16, col)
        elif k == "tired":
            for i, (x, y) in enumerate(((10, 20), (15, 14), (20, 8))):
                s = 3 - i // 2
                cv.hline(x, x + s, y, col)
                cv.line(x + s, y, x, y + s, col)
                cv.hline(x, x + s, y + s, col)
        elif k in ("pain", "bleeding"):
            for y in range(8, 24):
                w = int(math.sin((y - 8) / 16 * math.pi) * 5)
                cv.hline(16 - w, 16 + w, y, col)
        elif k == "sick":
            for (x, y) in ((12, 12), (19, 11), (15, 18), (20, 19), (11, 20)):
                cv.mask_fill(ellipse_mask(32, 32, x, y, 2.2, 2.2), col)
    elif name.startswith("doll_"):
        # health doll silhouette, tinted by state
        k = int(name[5:])
        col = [hexc("#5ad87a"), hexc("#b8d84a"), hexc("#e8c83a"), hexc("#e8803a"), hexc("#e83a3a"), hexc("#6a6a6a")][k]
        m = ellipse_mask(32, 32, 16, 7, 3.5, 3.5)
        m |= rrect_mask(32, 32, 12, 11, 19, 20, 1)
        m |= rrect_mask(32, 32, 9, 11, 10, 20, 0) | rrect_mask(32, 32, 21, 11, 22, 20, 0)
        m |= rrect_mask(32, 32, 12, 21, 14, 28, 0) | rrect_mask(32, 32, 17, 21, 19, 28, 0)
        cv.mask_fill(m, col)
        sel_outline(cv, color=hexc("#0d1118"))
    return cv


ICONS = ["slot_uniform", "slot_suit", "slot_head", "slot_mask", "slot_gloves", "slot_shoes", "slot_back", "slot_belt",
         "slot_id", "slot_ears", "slot_eyes", "slot_pocket", "hand_l", "hand_r", "act_drop", "act_swap", "act_throw",
         "act_pull", "act_resist", "act_internals", "act_combat", "act_combat_on", "act_walk", "act_run"] + \
[f"doll_{i}" for i in range(6)]


def build(manifest):
    from common import save
    pk = Packer(512)
    for i in range(3):
        for f in range(4):
            pk.add(f"fire_{i}_{f}", fire_frame(i, f))
    for v in range(3):
        pk.add(f"smoke_{v}", smoke(v))
        pk.add(f"smoke_dense_{v}", smoke(v, True))
        pk.add(f"gas_{v}", gas_cloud(v))
    for f in range(4):
        pk.add(f"sparks_{f}", sparks(f))
    for f in range(6):
        pk.add(f"explosion_{f}", explosion(f))
    pk.add("light", light_tex(128, 1.6))
    pk.add("light_soft", light_tex(128, 2.6))
    for s in range(3):
        pk.add(f"flake_{s}", flake(s))
    pk.add("streak", streak())
    pk.add("breath", breath_puff())
    pk.add("foam", foam())
    for v in range(6):
        pk.add(f"glass_frag_{v}", glass_frag(v))
    pk.add("glass_chip", glass_chip())
    for k in ("punch", "kick", "smash"):
        pk.add(f"atk_{k}", attack_effect(k))
    for n in ICONS:
        pk.add(f"ui_{n}", icon(n))
    import alerts
    for k in alerts.ALERTS:
        pk.add(f"ui_alert_{k}", alerts.icon(k))
    sheet, placed = pk.pack()
    save(sheet, "fx.png")
    manifest["fx"] = {k: list(v) for k, v in placed.items()}
