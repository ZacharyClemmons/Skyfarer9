"""More station dressing, tg-style: IV drips, bar stools, a jukebox and an arcade cabinet,
noticeboards, NanoMed wall cabinets, showers, toilets and mirrors, benches, R&D machines
(protolathe, destructive analyzer, server racks), wardrobes, a display case, wall clocks,
tool pegboards, floor guide lines and arrows. Packed into objects.png by objects.build()."""
import numpy as np

from common import Canvas, ellipse_mask, hexc, ramp, rng_for, rrect_mask, sel_outline, shade, shaded_fill


def _S(w=32, h=32):
    from objects import Sprite
    return Sprite(w, h)


def iv_drip():
    from objects import contact_shadow
    sp = _S(32, 48)
    cv = sp.cv
    contact_shadow(cv, 10, 21, 46)
    p = ramp("#b0b8c4", 5, 0.4)
    cv.vline(15, 10, 44, p[3])
    cv.vline(16, 10, 44, p[1])
    for x in range(10, 22):
        cv.px(x, 44, p[2])
    cv.px(10, 45, p[1])
    cv.px(21, 45, p[1])
    cv.hline(12, 20, 9, p[3])
    bag = rrect_mask(32, 48, 17, 10, 22, 19, 2)
    shaded_fill(cv, bag, "#d84a4a", 0.35)
    for y in range(12, 18):
        cv.px(18, y, hexc("#ff9a8a", 0.7))
    cv.vline(20, 20, 30, hexc("#e8e8e8", 0.7))
    sel_outline(cv, 0.5)
    return sp


def bar_stool():
    from objects import contact_shadow
    sp = _S()
    cv = sp.cv
    contact_shadow(cv, 10, 21, 29)
    seat = ellipse_mask(32, 32, 15.5, 15, 6, 3.5)
    shaded_fill(cv, seat, "#8a2a33", 0.35)
    cv.vline(15, 18, 27, hexc("#9aa3b3"))
    cv.vline(16, 18, 27, hexc("#6a7486"))
    cv.hline(12, 19, 23, hexc("#8a93a3"))
    cv.hline(12, 19, 28, hexc("#6a7486"))
    sel_outline(cv, 0.5)
    return sp


def jukebox():
    from objects import box3d, contact_shadow
    sp = _S(32, 48)
    cv = sp.cv
    contact_shadow(cv, 6, 25, 46)
    box3d(cv, 6, 12, 25, 45, 3, "#6a3a22", 0.4)
    arch = ellipse_mask(32, 48, 15.5, 16, 9, 7) & (np.mgrid[0:48, 0:32][0] < 20)
    shaded_fill(cv, arch, "#d8a050", 0.4)
    for i, c in enumerate(("#ff5a8a", "#ffd84a", "#5ae8ff", "#7aff7a")):
        for x in range(9, 23):
            sp.g(x, 22 + i * 2, hexc(c))
    cv.rect(10, 32, 21, 40, hexc("#2a160e"))
    for x in range(11, 21, 2):
        cv.vline(x, 33, 39, hexc("#4a2a18"))
    return sp


def arcade():
    from objects import box3d, contact_shadow, screen
    sp = _S(32, 48)
    cv = sp.cv
    rng = rng_for("arcade")
    contact_shadow(cv, 7, 24, 46)
    box3d(cv, 7, 8, 24, 45, 3, "#2a2e48", 0.4)
    cv.rect(9, 9, 22, 12, hexc("#ff5a8a"))
    screen(sp, 10, 15, 21, 25, "#7aff7a", rng, "graph")
    cv.rect(9, 28, 22, 31, hexc("#3a3f5a"))
    cv.px(12, 29, hexc("#d83a3a"))
    cv.px(17, 29, hexc("#e8d84a"))
    cv.px(19, 30, hexc("#4a8aff"))
    return sp


def noticeboard():
    sp = _S()
    cv = sp.cv
    body = rrect_mask(32, 32, 5, 6, 26, 21, 1)
    shaded_fill(cv, body, "#8a5a3b", 0.3)
    cv.rect(7, 8, 24, 19, hexc("#c8a070"))
    for (x0, y0, x1, y1, c) in ((8, 9, 13, 14, "#f4f0e8"), (15, 10, 20, 16, "#e8e0a0"), (21, 9, 23, 13, "#a0c8e8"), (10, 15, 16, 18, "#f0c8c8")):
        cv.rect(x0, y0, x1, y1, hexc(c))
        cv.px(x0 + 1, y0, hexc("#d83a3a"))
    sel_outline(cv, 0.5)
    return sp


def med_cabinet():
    """NanoMed wall vendor."""
    sp = _S()
    cv = sp.cv
    body = rrect_mask(32, 32, 8, 3, 23, 22, 2)
    shaded_fill(cv, body, "#e8eef4", 0.3)
    cv.rect(10, 5, 21, 11, hexc("#2a3a4a"))
    for x in range(11, 21):
        sp.g(x, 7, hexc("#5ad0ff"))
    cv.rect(14, 13, 17, 19, hexc("#4ab8d8"))
    cv.rect(12, 15, 19, 17, hexc("#4ab8d8"))
    sel_outline(cv, 0.5)
    return sp


def shower():
    sp = _S()
    cv = sp.cv
    p = ramp("#b0b8c4", 5, 0.4)
    cv.vline(15, 1, 10, p[2])
    cv.hline(12, 19, 11, p[3])
    for x in range(12, 20, 2):
        cv.px(x, 12, hexc("#5ab8e8"))
    for y in range(14, 30):
        cv.px(8, y, hexc("#9fd0ec", 0.25))
        cv.px(23, y, hexc("#9fd0ec", 0.25))
    grate = rrect_mask(32, 32, 12, 24, 19, 28, 1)
    shaded_fill(cv, grate, "#6a7486", 0.3)
    for x in range(13, 19, 2):
        cv.px(x, 26, hexc("#1d2230"))
    return sp


def toilet():
    from objects import contact_shadow
    sp = _S()
    cv = sp.cv
    contact_shadow(cv, 10, 21, 29)
    tank = rrect_mask(32, 32, 11, 6, 20, 13, 1)
    shaded_fill(cv, tank, "#e8eef4", 0.3)
    bowl = ellipse_mask(32, 32, 15.5, 20, 5.5, 6)
    shaded_fill(cv, bowl, "#f4f8ff", 0.3)
    inner = ellipse_mask(32, 32, 15.5, 20, 3, 3.5)
    shaded_fill(cv, inner, "#9fd0ec", 0.3)
    sel_outline(cv, 0.5)
    return sp


def mirror():
    sp = _S()
    cv = sp.cv
    frame = rrect_mask(32, 32, 9, 4, 22, 20, 2)
    shaded_fill(cv, frame, "#b0b8c4", 0.3)
    glass = rrect_mask(32, 32, 11, 6, 20, 18, 1)
    shaded_fill(cv, glass, "#9fd0ec", 0.35)
    for i in range(5):
        cv.px(13 + i, 8 + i, hexc("#e8f8ff"))
    sel_outline(cv, 0.5)
    return sp


def bench(col="#6a7486"):
    from objects import contact_shadow
    sp = _S()
    cv = sp.cv
    contact_shadow(cv, 2, 29, 27)
    p = ramp(col, 6, 0.4)
    cv.rect(1, 14, 30, 19, p[4])
    cv.hline(1, 30, 14, p[5])
    cv.hline(1, 30, 20, p[2])
    for x in (4, 27):
        cv.vline(x, 21, 25, p[1])
    sel_outline(cv, 0.5)
    return sp


def rnd_machine(kind):
    from objects import box3d, contact_shadow, screen
    sp = _S(32, 40)
    cv = sp.cv
    rng = rng_for("rnd" + kind)
    contact_shadow(cv, 3, 28, 38)
    if kind == "protolathe":
        box3d(cv, 3, 12, 28, 37, 4, "#8a93a3", 0.4)
        cv.rect(6, 16, 25, 24, hexc("#2a3040"))
        for x in range(8, 24, 3):
            sp.g(x, 20, hexc("#ffb05a"))
        cv.rect(8, 28, 23, 34, hexc("#5a6272"))
        cv.hline(8, 23, 28, hexc("#b87ae8"))
    elif kind == "analyzer":
        box3d(cv, 4, 14, 27, 37, 4, "#6a7486", 0.4)
        ring = ellipse_mask(32, 40, 15.5, 24, 7, 5) & ~ellipse_mask(32, 40, 15.5, 24, 4, 3)
        shaded_fill(cv, ring, "#b87ae8", 0.4)
        sp.g(15, 24, hexc("#e8c8ff"))
        sp.g(16, 24, hexc("#e8c8ff"))
    else:  # server rack
        box3d(cv, 7, 4, 24, 37, 3, "#2a2e38", 0.35)
        for y in range(9, 35, 4):
            cv.hline(9, 22, y, hexc("#141820"))
            for x in range(10, 21, 3):
                sp.g(x, y + 2, hexc("#5aff7a" if rng.random() < 0.7 else "#ffb84a"))
    return sp


def wardrobe():
    from objects import box3d, contact_shadow
    sp = _S(32, 48)
    cv = sp.cv
    contact_shadow(cv, 5, 26, 46)
    box3d(cv, 5, 6, 26, 45, 3, "#6a4a2a", 0.4)
    cv.vline(15, 10, 43, hexc("#3a2616"))
    cv.px(13, 26, hexc("#d8b050"))
    cv.px(18, 26, hexc("#d8b050"))
    return sp


def display_case():
    from objects import box3d, contact_shadow
    sp = _S(32, 40)
    cv = sp.cv
    contact_shadow(cv, 7, 24, 38)
    box3d(cv, 7, 24, 24, 37, 2, "#6a4a2a", 0.4)
    glass = rrect_mask(32, 40, 8, 8, 23, 23, 1)
    ys, xs = np.nonzero(glass)
    for y, x in zip(ys, xs):
        cv.px(x, y, hexc("#9fd0ec", 0.35))
    for x in range(8, 24):
        cv.px(x, 8, hexc("#e8f8ff", 0.7))
    # the captain's antique laser inside
    cv.rect(11, 17, 20, 18, hexc("#d8b050"))
    cv.px(20, 16, hexc("#ff4a3a"))
    return sp


def wall_clock():
    sp = _S()
    cv = sp.cv
    face = ellipse_mask(32, 32, 15.5, 12, 6, 6)
    shaded_fill(cv, face, "#e8eef4", 0.25)
    for y in range(7, 13):
        cv.px(15, y, hexc("#1d1b22"))
    for x in range(16, 20):
        cv.px(x, 12, hexc("#1d1b22"))
    cv.px(15, 12, hexc("#d83a3a"))
    sel_outline(cv, 0.6)
    return sp


def pegboard():
    sp = _S()
    cv = sp.cv
    body = rrect_mask(32, 32, 4, 4, 27, 20, 1)
    shaded_fill(cv, body, "#8a7a5a", 0.25)
    for y in range(6, 20, 3):
        for x in range(6, 27, 3):
            cv.px(x, y, hexc("#5a4a3a"))
    # hanging tools: wrench, screwdriver, hammer
    cv.vline(9, 7, 16, hexc("#b0b8c4"))
    cv.rect(8, 6, 10, 7, hexc("#b0b8c4"))
    cv.vline(15, 7, 12, hexc("#b0b8c4"))
    cv.vline(15, 13, 17, hexc("#e8c83a"))
    cv.rect(20, 7, 24, 9, hexc("#6a7486"))
    cv.vline(22, 10, 17, hexc("#8a5a3b"))
    sel_outline(cv, 0.5)
    return sp


def guide_line(col, side):
    """A painted floor line along one side of a tile (tg's warning / guide lines)."""
    cv = Canvas()
    c = hexc(col, 0.85)
    for i in range(32):
        for k in (0, 1):
            if side == "n":
                cv.px(i, 1 + k, c)
            elif side == "s":
                cv.px(i, 29 + k, c)
            elif side == "w":
                cv.px(1 + k, i, c)
            else:
                cv.px(29 + k, i, c)
    from objects import Sprite
    sp = Sprite()
    sp.cv.a[:] = cv.a
    return sp


def arrow(col, side):
    from objects import Sprite
    sp = Sprite()
    cv = sp.cv
    c = hexc(col, 0.8)
    for y in range(9, 23):
        w = (y - 9) // 2 if y < 17 else 1
        for x in range(16 - w, 17 + w):
            if y < 17 or 14 <= x <= 17:
                cv.px(x, y, c)
    if side != "n":
        k = {"e": 3, "s": 2, "w": 1}[side]
        cv.a[:] = np.rot90(cv.a, k)
    return sp


def curtain(open_, col="#7ab8c8"):
    """tg privacy curtain on a ceiling rail: drawn across the tile, or bunched to one side."""
    sp = _S(32, 48)
    cv = sp.cv
    rail = ramp("#b0b8c4", 5, 0.4)
    cv.hline(0, 31, 6, rail[3])
    cv.hline(0, 31, 7, rail[1])
    p = ramp(col, 5, 0.35)
    x1 = 7 if open_ else 32
    folds = (3, 4, 3, 2, 1, 2)
    for x in range(0, x1):
        i = folds[x % 6] if not open_ else folds[(x * 2) % 6]
        for y in range(8, 44):
            cv.px(x, y, p[i])
        cv.px(x, 44, p[0] if x % 3 else p[1])
        if x % 4 == 0:
            cv.px(x, 6, rail[4])  # rings
    if open_:
        for x in range(7, 32, 4):
            cv.px(x, 6, rail[4])
    return sp


def op_table():
    """tg operating table: a padded slab on a steel pedestal, with a lamp arm."""
    from objects import contact_shadow
    sp = _S()
    cv = sp.cv
    contact_shadow(cv, 4, 27, 29)
    top = rrect_mask(32, 32, 3, 10, 28, 20, 2)
    shaded_fill(cv, top, "#b8c2cc", 0.35)
    pad = rrect_mask(32, 32, 5, 11, 26, 17, 2)
    shaded_fill(cv, pad, "#4ab8a8", 0.3)
    p = ramp("#8a93a3", 5, 0.4)
    cv.rect(13, 21, 18, 27, p[2])
    cv.hline(10, 21, 28, p[1])
    sel_outline(cv, 0.5)
    return sp


def add_all(pk):
    pk.add("op_table", op_table())
    pk.add("curtain_closed", curtain(False))
    pk.add("curtain_open", curtain(True))
    pk.add("shower_curtain_closed", curtain(False, "#e8eef4"))
    pk.add("shower_curtain_open", curtain(True, "#e8eef4"))
    pk.add("iv_drip", iv_drip())
    pk.add("bar_stool", bar_stool())
    pk.add("jukebox", jukebox())
    pk.add("arcade", arcade())
    pk.add("noticeboard", noticeboard())
    pk.add("med_cabinet", med_cabinet())
    pk.add("shower", shower())
    pk.add("toilet", toilet())
    pk.add("mirror", mirror())
    pk.add("bench", bench())
    pk.add("bench_wood", bench("#8a5a3b"))
    for k in ("protolathe", "analyzer", "server"):
        pk.add(f"rnd_{k}", rnd_machine(k))
    pk.add("wardrobe", wardrobe())
    pk.add("display_case", display_case())
    pk.add("wall_clock", wall_clock())
    pk.add("pegboard", pegboard())
    for name, col in (("yellow", "#e8c83a"), ("white", "#e8eef4"), ("red", "#d84a4a"), ("blue", "#4a8ad8")):
        for side in "nesw":
            pk.add(f"line_{name}_{side}", guide_line(col, side))
    for side in "nesw":
        pk.add(f"arrow_{side}", arrow("#e8c83a", side))
