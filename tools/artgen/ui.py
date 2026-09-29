"""The HUD's own art (ui.png): nine-slice frames for panels, slots, buttons, tabs, title
bars, tooltips and bar wells, 16x16 icons (shown at 2x), and the body doll's zones.
Gunmetal and frost: dark steel panels with a bevel and corner rivets, recessed slots,
raised buttons, a cold cyan accent. Every frame keeps its corners inside SLICE px so
Godot can stretch the middle."""
import math

import numpy as np

from common import Canvas, ellipse_mask, hexc, mix, rrect_mask, shade

OUTLINE = hexc("#05080c")
BODY_TOP = hexc("#243042")
BODY_BOT = hexc("#19222e")
BEVEL_HI = hexc("#5f7a92")
BEVEL_LO = hexc("#0e141b")
ACCENT = hexc("#7fd4ff")
WARN = hexc("#ffb84a")
ICON = hexc("#d6e6f2")
ICON_DIM = hexc("#8aa6bc")

SLICES = {}  # name -> corner size (for the engine: StyleBoxTexture margins)


def _with_alpha(c, a):
    return np.array([c[0], c[1], c[2], a])


def frame(w, h, corner, top, bot, hi, lo, alpha=1.0, rivets=False, accent=None, recessed=False):
    cv = Canvas(w, h)
    for y in range(h):
        t = y / max(1, h - 1)
        c = mix(top, bot, t)
        for x in range(w):
            cv.px(x, y, _with_alpha(c, alpha))
    # bevel: light top-left, dark bottom-right (swapped for recessed wells)
    a, b = (lo, hi) if recessed else (hi, lo)
    for x in range(1, w - 1):
        cv.px(x, 1, _with_alpha(a, 1.0))
        cv.px(x, h - 2, _with_alpha(b, 1.0))
    for y in range(1, h - 1):
        cv.px(1, y, _with_alpha(a, 1.0))
        cv.px(w - 2, y, _with_alpha(b, 1.0))
    if recessed:
        for x in range(2, w - 2):
            cv.px(x, 2, _with_alpha(shade(lo, -0.2), 0.8))
        for y in range(2, h - 2):
            cv.px(2, y, _with_alpha(shade(lo, -0.2), 0.8))
    # outline with trimmed corners
    for x in range(1, w - 1):
        cv.px(x, 0, _with_alpha(OUTLINE, 1.0))
        cv.px(x, h - 1, _with_alpha(OUTLINE, 1.0))
    for y in range(1, h - 1):
        cv.px(0, y, _with_alpha(OUTLINE, 1.0))
        cv.px(w - 1, y, _with_alpha(OUTLINE, 1.0))
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        cv.px(x, y, np.array([0.0, 0.0, 0.0, 0.0]))
    if rivets:
        for (x, y) in ((4, 4), (w - 6, 4), (4, h - 6), (w - 6, h - 6)):
            cv.px(x, y, _with_alpha(shade(hi, 0.2), 1.0))
            cv.px(x + 1, y + 1, _with_alpha(lo, 1.0))
            cv.px(x + 1, y, _with_alpha(hi, 1.0))
            cv.px(x, y + 1, _with_alpha(shade(lo, 0.3), 1.0))
    if accent is not None:
        for x in range(corner, w - corner):
            cv.px(x, 2, _with_alpha(accent, 0.55))
    return cv


def panel():
    cv = frame(48, 48, 10, BODY_TOP, BODY_BOT, BEVEL_HI, BEVEL_LO, 1.0, rivets=True)
    # a faint horizontal brushed texture
    for y in range(3, 45, 3):
        for x in range(3, 45):
            c = cv.get(x, y)
            cv.px(x, y, np.array([c[0] * 0.94, c[1] * 0.94, c[2] * 0.94, c[3]]))
    return cv


def panel_title():
    return frame(48, 20, 6, hexc("#2c3a4e"), hexc("#223044"), BEVEL_HI, BEVEL_LO, 1.0, accent=ACCENT)


def slot(state="normal"):
    body = {"normal": (hexc("#101720"), hexc("#141c27")), "hot": (hexc("#172230"), hexc("#1b2838")), "active": (hexc("#142434"), hexc("#18304a"))}[state]
    cv = frame(32, 32, 8, body[0], body[1], hexc("#3a4e64"), hexc("#070a0e"), 1.0, recessed=True)
    if state == "active":
        for x in range(3, 29):
            cv.px(x, 29, _with_alpha(ACCENT, 1.0))
            cv.px(x, 28, _with_alpha(ACCENT, 0.4))
        for (x, y) in ((1, 1), (30, 1), (1, 30), (30, 30)):
            cv.px(x, y, _with_alpha(ACCENT, 1.0))
    if state == "hot":
        for (x, y) in ((1, 1), (30, 1), (1, 30), (30, 30)):
            cv.px(x, y, _with_alpha(BEVEL_HI, 1.0))
    return cv


def button(state="normal"):
    top, bot, hi, lo = {
        "normal": (hexc("#34445a"), hexc("#26323f"), hexc("#6a86a0"), hexc("#10161d")),
        "hover": (hexc("#3e536c"), hexc("#2c3b4c"), hexc("#8fc0dc"), hexc("#10161d")),
        "pressed": (hexc("#1c2632"), hexc("#222e3c"), hexc("#10161d"), hexc("#5a7690")),
        "disabled": (hexc("#1f2630"), hexc("#1b2129"), hexc("#2c3642"), hexc("#12171d")),
        "on": (hexc("#2e5a74"), hexc("#23465c"), hexc("#9fe0ff"), hexc("#0e1a24")),
    }[state]
    cv = frame(24, 24, 7, top, bot, hi, lo, 1.0)
    if state == "hover":
        for x in range(2, 22):
            cv.px(x, 0, _with_alpha(ACCENT, 1.0))
    return cv


def tab(active=False):
    top, bot = (hexc("#2c3a4e"), hexc("#243042")) if active else (hexc("#1c2531"), hexc("#18202a"))
    cv = frame(24, 20, 6, top, bot, BEVEL_HI if active else hexc("#3a4a5c"), BEVEL_LO, 1.0)
    if active:
        for x in range(2, 22):
            cv.px(x, 1, _with_alpha(ACCENT, 1.0))
    return cv


def tooltip():
    return frame(24, 24, 6, hexc("#2a3648"), hexc("#222c3a"), hexc("#7fa3bf"), BEVEL_LO, 0.97)


def well():
    """The recessed channel a vertical bar fills."""
    return frame(12, 24, 4, hexc("#0b1016"), hexc("#0e141c"), hexc("#34465a"), hexc("#05080c"), 1.0, recessed=True)


def fill(col):
    """Bar fill: a bright top edge and soft vertical banding."""
    cv = Canvas(8, 16)
    base = hexc(col)
    for y in range(16):
        for x in range(8):
            c = shade(base, 0.25 if x == 1 else (-0.18 if x >= 6 else 0.0))
            if y % 4 == 3:
                c = shade(c, -0.12)
            cv.px(x, y, _with_alpha(c, 1.0))
    for x in range(8):
        cv.px(x, 0, _with_alpha(shade(base, 0.5), 1.0))
    return cv


def line_edit():
    return frame(24, 24, 6, hexc("#0b1016"), hexc("#0e141c"), hexc("#34465a"), hexc("#05080c"), 1.0, recessed=True)


# ------------------------------------------------------------------ icons (16x16)
def _ic():
    return Canvas(16, 16)


def _px(cv, pts, c):
    for (x, y) in pts:
        cv.px(x, y, c)


def _rect(cv, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cv.px(x, y, c)


def _load_icons():
    """Hand-drawn 16x16 icons from ui_icons.txt."""
    import os
    out, cur, rows, col, extra = {}, None, [], None, {}
    lines = []
    # ui_icons_v2.txt is the hand-drawn set; it comes last so its icons replace the old ones
    for fn in ("ui_icons.txt", "ui_icons_actions.txt", "ui_icons_v2.txt", "ui_icons_genetics.txt"):
        lines += open(os.path.join(os.path.dirname(__file__), fn), encoding="utf-8").read().split(chr(10))
        lines.append("@__end__ #000000")
    for line in lines:
        line = line.rstrip(chr(10))
        if line.startswith("#") or not line.strip():
            continue
        if line.startswith("@"):
            if cur:
                out[cur] = (col, rows, extra)
            parts = line[1:].split()
            cur, col, rows = parts[0], parts[1], []
            # extra colours for this icon: "g=#9aa8b8" maps the letter g to that colour
            extra = dict(p.split("=", 1) for p in parts[2:] if "=" in p)
            continue
        rows.append(line)
    if cur:
        out[cur] = (col, rows, extra)
    out.pop("__end__", None)
    return out


_ICONS = None


def icon(name):
    global _ICONS
    if _ICONS is None:
        _ICONS = _load_icons()
    if name in _ICONS:
        col, rows, extra = (_ICONS[name] + ({},))[:3]
        base = hexc(col)
        # '+' light, '#' base, '-' shade, '=' deep shade, 'w' glint, 'o' outline
        pal = {"#": base, "+": shade(base, 0.45), "-": shade(base, -0.35), "=": shade(base, -0.6), "o": OUTLINE,
               "7": ACCENT, "*": hexc("#d8e0ea"), ":": hexc("#7a8494"), "w": hexc("#ffffff")}
        for k, v in extra.items():
            pal[k] = hexc(v)
        cv = _ic()
        for y, r in enumerate(rows[:16]):
            for x, ch in enumerate(r[:16]):
                if ch in pal:
                    cv.px(x, y, _with_alpha(pal[ch], 1.0))
        return cv
    return _icon_drawn(name)


def _icon_drawn(name):
    cv = _ic()
    c, d = ICON, ICON_DIM
    if name == "skills":  # a star
        for y in range(16):
            for x in range(16):
                a = math.atan2(y - 7.5, x - 7.5)
                r = math.hypot(x - 7.5, y - 7.5)
                lim = 3.0 + 3.8 * (0.5 + 0.5 * math.cos(5 * (a + math.pi / 2)))
                if r <= lim:
                    cv.px(x, y, c if r < lim - 1.2 else d)
    elif name == "log":  # a book
        _rect(cv, 2, 3, 13, 13, d)
        _rect(cv, 3, 3, 7, 12, c)
        _rect(cv, 8, 3, 12, 12, c)
        for y in (5, 7, 9):
            _rect(cv, 4, y, 6, y, d)
            _rect(cv, 9, y, 11, y, d)
    elif name == "crew":  # two people
        for cx, col in ((5, d), (10, c)):
            _rect(cv, cx - 1, 3, cx + 1, 5, col)
            _rect(cv, cx - 2, 7, cx + 2, 13, col)
    elif name == "help":  # a question mark
        _px(cv, [(6, 3), (7, 2), (8, 2), (9, 2), (10, 3), (10, 4), (10, 5), (9, 6), (8, 7), (8, 8), (8, 9), (7, 9)], c)
        _rect(cv, 7, 12, 8, 13, c)
        _rect(cv, 7, 2, 9, 2, c)
        _rect(cv, 6, 3, 6, 4, c)
    elif name == "layout":  # four panes
        for (x0, y0) in ((2, 2), (9, 2), (2, 9), (9, 9)):
            _rect(cv, x0, y0, x0 + 4, y0 + 4, c if (x0, y0) != (9, 9) else ACCENT)
    elif name == "heart":
        col = hexc("#ff5a5a")
        for y in range(16):
            for x in range(16):
                xx, yy = (x - 7.5) / 6.5, (y - 6.5) / 6.5
                if (xx * xx + yy * yy - 0.35) ** 3 - xx * xx * yy ** 3 * 1.2 <= 0:
                    cv.px(x, y, col if not (x < 6 and y < 6) else shade(col, 0.35))
    elif name == "stamina":  # a lightning bolt
        col = hexc("#ffd84a")
        _px(cv, [(9, 1), (8, 2), (8, 3), (7, 4), (7, 5), (6, 6), (6, 7), (7, 7), (8, 7), (9, 7), (9, 8), (8, 9), (8, 10), (7, 11), (7, 12), (6, 13), (6, 14)], col)
        _px(cv, [(9, 2), (8, 4), (8, 5), (7, 6), (10, 7), (9, 9), (8, 11)], shade(col, -0.2))
    elif name == "temp":  # a thermometer
        col = hexc("#7fd4ff")
        _rect(cv, 7, 2, 8, 10, d)
        _rect(cv, 7, 6, 8, 10, col)
        for (x, y) in ((6, 11), (7, 11), (8, 11), (9, 11), (6, 12), (7, 12), (8, 12), (9, 12), (7, 13), (8, 13)):
            cv.px(x, y, col)
    elif name == "food":  # a drumstick-ish ration bar
        col = hexc("#e8a84a")
        _rect(cv, 4, 5, 11, 11, col)
        _rect(cv, 5, 4, 10, 4, col)
        _rect(cv, 5, 12, 10, 12, shade(col, -0.25))
        _rect(cv, 5, 6, 6, 7, shade(col, 0.35))
    elif name == "water":  # a droplet
        col = hexc("#4ab8ff")
        for y in range(2, 15):
            w = int(math.sin((y - 2) / 13 * math.pi * 0.95) * 5) if y > 5 else (y - 2) // 2
            _rect(cv, 8 - w, y, 7 + w, y, col)
        _px(cv, [(6, 8), (6, 9), (5, 10)], shade(col, 0.45))
    elif name == "energy":  # a crescent moon
        col = hexc("#b89aff")
        for y in range(16):
            for x in range(16):
                if math.hypot(x - 7.5, y - 7.5) <= 6 and math.hypot(x - 10, y - 5.5) > 5:
                    cv.px(x, y, col)
    elif name == "stress":  # a jagged spark
        col = hexc("#ff7a9a")
        for i in range(12):
            x = 2 + i
            y = 8 + (3 if i % 2 else -3) * (1 if i % 4 < 2 else 0)
            _rect(cv, x, min(8, y), x, max(8, y), col)
    elif name == "guard":  # a shield
        col = hexc("#9fb8cc")
        for y in range(2, 15):
            w = 6 if y < 9 else 6 - (y - 8)
            _rect(cv, 8 - w, y, 7 + w, y, col)
        _rect(cv, 7, 3, 8, 12, shade(col, 0.3))
    elif name == "guard_on":
        col = hexc("#ffd84a")
        for y in range(2, 15):
            w = 6 if y < 9 else 6 - (y - 8)
            _rect(cv, 8 - w, y, 7 + w, y, col)
        _rect(cv, 7, 3, 8, 12, shade(col, 0.4))
    elif name == "alert":  # small triangle for the alert pill
        col = WARN
        for y in range(3, 14):
            w = (y - 3) // 2
            _rect(cv, 8 - w, y, 7 + w, y, col)
        _rect(cv, 7, 6, 8, 10, hexc("#1d1b22"))
        _rect(cv, 7, 12, 8, 12, hexc("#1d1b22"))
    elif name == "location":  # a map pin
        col = ACCENT
        for y in range(2, 9):
            w = int(math.sqrt(max(0, 9 - (y - 5) ** 2)))
            _rect(cv, 8 - w, y, 7 + w, y, col)
        for y in range(9, 14):
            w = (13 - y) // 2
            _rect(cv, 8 - w, y, 7 + w, y, col)
        _rect(cv, 7, 4, 8, 5, hexc("#101720"))
    elif name == "clock":
        for a in range(0, 360, 12):
            cv.px(int(round(7.5 + math.cos(math.radians(a)) * 6)), int(round(7.5 + math.sin(math.radians(a)) * 6)), c)
        _rect(cv, 7, 4, 8, 8, c)
        _rect(cv, 8, 8, 10, 8, c)
    return cv


# ------------------------------------------------------------------ the body doll
def _head(x, y):
    return math.hypot(x - 15.5, y - 6.5) <= 5.4


DOLL_ZONES = {
    "eyes": lambda x, y: y in (5, 6) and (13 <= x <= 14 or 17 <= x <= 18),
    "mouth": lambda x, y: y == 9 and 14 <= x <= 17,
    "head": lambda x, y: _head(x, y) and not (y in (5, 6) and (13 <= x <= 14 or 17 <= x <= 18)) and not (y == 9 and 14 <= x <= 17),
    "chest": lambda x, y: 10 <= x <= 21 and 12 <= y <= 25 and not (y <= 13 and (x == 10 or x == 21)),
    "groin": lambda x, y: 11 <= x <= 20 and 26 <= y <= 29,
    "r_arm": lambda x, y: 5 <= x <= 8 and 13 <= y <= 24 and not (y == 13 and x == 5),
    "l_arm": lambda x, y: 23 <= x <= 26 and 13 <= y <= 24 and not (y == 13 and x == 26),
    "r_hand": lambda x, y: 5 <= x <= 8 and 26 <= y <= 29,
    "l_hand": lambda x, y: 23 <= x <= 26 and 26 <= y <= 29,
    "r_leg": lambda x, y: 11 <= x <= 14 and 31 <= y <= 41,
    "l_leg": lambda x, y: 17 <= x <= 20 and 31 <= y <= 41,
    "r_foot": lambda x, y: 9 <= x <= 14 and 43 <= y <= 45,
    "l_foot": lambda x, y: 17 <= x <= 22 and 43 <= y <= 45,
}


def doll_zone(z):
    """White mask of one zone (tinted in the engine), with a darker lower half for shape."""
    cv = Canvas(32, 48)
    fn = DOLL_ZONES[z]
    for y in range(48):
        for x in range(32):
            if fn(x, y):
                edge = not all(fn(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                v = 0.62 if edge else (0.95 if (x + y) % 5 else 0.88)
                cv.px(x, y, np.array([v, v, v, 1.0]))
    return cv


def doll_outline():
    cv = Canvas(32, 48)
    inside = lambda x, y: any(fn(x, y) for fn in DOLL_ZONES.values())
    for y in range(48):
        for x in range(32):
            if not inside(x, y) and any(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.px(x, y, np.array([0.02, 0.03, 0.05, 1.0]))
    return cv


def _x2(cv):
    return Canvas.from_array(np.repeat(np.repeat(cv.a, 2, axis=0), 2, axis=1))


def build(manifest):
    from common import save
    from objects import Packer
    pk = Packer(512)
    pk.add("panel", panel())
    pk.add("panel_title", panel_title())
    for st in ("normal", "hot", "active"):
        pk.add("slot_" + st, slot(st))
    for st in ("normal", "hover", "pressed", "disabled", "on"):
        pk.add("button_" + st, button(st))
    pk.add("tab", tab(False))
    pk.add("tab_active", tab(True))
    pk.add("tooltip", tooltip())
    pk.add("well", well())
    pk.add("line_edit", line_edit())
    for name, col in (("health", "#e8584a"), ("stamina", "#e8c83a"), ("temp", "#5ac0f0"), ("food", "#e8a04a"),
                      ("water", "#3aa8f0"), ("energy", "#a88aff"), ("stress", "#ff6a8a"), ("xp", "#7fd4ff")):
        pk.add("fill_" + name, fill(col))
    for n in _load_icons():
        pk.add("icon_" + n, icon(n))
    for z in DOLL_ZONES:
        pk.add("doll_" + z, doll_zone(z))
    pk.add("doll_outline", doll_outline())
    # drawn at 1x, shipped at 2x: chunky pixels at 1080p
    pk.items = [(n, _x2(cv)) for n, cv in pk.items]
    sheet, placed = pk.pack()
    save(sheet, "ui.png")
    manifest["ui"] = {k: list(v) for k, v in placed.items()}
