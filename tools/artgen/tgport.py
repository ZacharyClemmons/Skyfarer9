"""Sprites for the tg features ported in the machines/atmos pass: firelocks, fire alarm
states, the holofan and its barrier, the autolathe, and the odd item those machines make.
objects.build() calls add_objects(), items.build() calls add_items()."""
from common import Canvas, hexc, ramp, rrect_mask, sel_outline, shaded_fill


def _S(w=32, h=32):
    from objects import Sprite
    return Sprite(w, h)


# ------------------------------------------------------------------ firelocks
def firelock(frame, lights=""):
    """frame 0 = open (shutter up in the ceiling) .. 3 = shut. 32x32, drawn over a doorway."""
    sp = _S()
    cv = sp.cv
    rail = ramp("#6a5a3a", 5, 0.4)
    # floor rails at the jambs, always visible
    for x in (1, 2, 29, 30):
        cv.px(x, 30, rail[3 if x in (1, 29) else 1])
        cv.px(x, 29, rail[2])
    if frame == 0:
        # the shutter's bottom lip peeking out of the lintel
        for x in range(3, 29):
            cv.px(x, 6, hexc("#1d1b22") if (x // 2) % 2 else hexc("#e0b23a"))
        return sp
    bottom = [6, 14, 22, 30][frame]
    p = ramp("#a8403a", 7, 0.35)
    for y in range(1, bottom + 1):
        for x in range(2, 30):
            i = 3
            if y % 4 == 0:
                i = 1  # corrugation
            elif y % 4 == 1:
                i = 5
            if x in (2, 29):
                i = max(0, i - 2)
            cv.px(x, y, p[i])
    # hazard band along the bottom edge of the shutter
    for y in range(max(1, bottom - 3), bottom + 1):
        for x in range(2, 30):
            cv.px(x, y, hexc("#1d1b22") if ((x + y) // 2) % 2 else hexc("#e0b23a"))
    cv.hline(2, 29, bottom, hexc("#16141d"))
    cv.vline(1, 0, bottom, hexc("#16141d"))
    cv.vline(30, 0, bottom, hexc("#16141d"))
    if lights:
        col = "#ff4a3a" if lights == "hot" else "#4ab8ff"
        for x in (6, 7, 24, 25):
            sp.g(x, 3, hexc(col))
            sp.g(x, 4, hexc(col))
    return sp


def fire_alarm(active):
    from objects import box3d, lamp
    sp = _S()
    cv = sp.cv
    box3d(cv, 11, 7, 20, 17, 2, "#c83a3a", 0.35)
    cv.rect(13, 12, 18, 15, hexc("#e8e0d0"))
    cv.hline(14, 17, 13, hexc("#c83a3a"))
    lamp(sp, 15, 9, "#ff3a2a" if active else "#5aff7a")
    lamp(sp, 16, 9, "#ff3a2a" if active else "#5aff7a")
    return sp


def holofan_barrier():
    sp = _S()
    for y in range(4, 30):
        for x in range(3, 29):
            edge = x in (3, 28) or y in (4, 29)
            if edge or (x + y) % 6 == 0:
                sp.g(x, y, hexc("#6ae8ff", 0.85 if edge else 0.35))
            else:
                sp.cv.px(x, y, hexc("#4ab8e8", 0.12))
    # fan glyph
    for dx, dy in ((0, -3), (3, 0), (0, 3), (-3, 0), (0, 0), (1, -2), (2, 1), (-1, 2), (-2, -1)):
        sp.g(16 + dx, 17 + dy, hexc("#c8f4ff", 0.9))
    return sp


def autolathe(on=False):
    from objects import box3d, contact_shadow, lamp, screen
    from common import rng_for
    sp = _S(32, 40)
    cv = sp.cv
    contact_shadow(cv, 3, 28, 38)
    box3d(cv, 3, 10, 28, 37, 5, "#b8c0cc", 0.35)
    # hopper on top
    cv.rect(8, 4, 23, 10, hexc("#6a7486"))
    cv.rect(10, 5, 21, 8, hexc("#2a2e38"))
    # output tray and window
    cv.rect(7, 27, 24, 33, hexc("#3a3e48"))
    cv.rect(8, 28, 23, 31, hexc("#1c2028"))
    screen(sp, 7, 16, 16, 22, "#5ad0ff", rng_for("autolathe"), "text")
    lamp(sp, 20, 18, "#ffcc4a" if on else "#5aff7a")
    lamp(sp, 23, 18, "#5aff7a")
    cv.hline(4, 27, 25, hexc("#d8a53a"))
    return sp


def add_objects(pk):
    for f in range(4):
        pk.add(f"firelock_{f}", firelock(f))
    pk.add("firelock_3_hot", firelock(3, "hot"))
    pk.add("firelock_3_cold", firelock(3, "cold"))
    pk.add("fire_alarm_on", fire_alarm(True))
    pk.add("fire_alarm_idle", fire_alarm(False))
    pk.add("holofan_barrier", holofan_barrier())
    pk.add("autolathe", autolathe())
    pk.add("autolathe_on", autolathe(True))
    import tgmed
    tgmed.add_objects(pk)
    tgmed.add_construction_objects(pk)
    tgmed.add_atmos_objects(pk)


# ------------------------------------------------------------------ items
def holofan():
    from items import Sprite, _fin
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 9, 12, 22, 24, 2)
    shaded_fill(cv, body, "#d8b83a", 0.35)
    cv.rect(11, 8, 20, 12, hexc("#6a7486"))
    cv.rect(13, 25, 17, 28, hexc("#3a3e48"))
    _fin(cv)
    for x in range(12, 20):
        sp.g(x, 9, hexc("#6ae8ff"))
    sp.g(15, 18, hexc("#6ae8ff"))
    sp.g(16, 18, hexc("#6ae8ff"))
    return sp


def circuit_board(col="#3a9a4a"):
    from items import _fin
    cv = Canvas()
    body = rrect_mask(32, 32, 8, 10, 23, 23, 1)
    shaded_fill(cv, body, col, 0.3)
    for x in range(10, 22, 3):
        cv.vline(x, 12, 21, hexc("#d8b84a", 0.8))
    cv.rect(13, 14, 18, 18, hexc("#1d1b22"))
    return _fin(cv)


def add_items(pk):
    pk.add("holofan", holofan())
    pk.add("circuit_board", circuit_board())
    import tgmed
    tgmed.add_items(pk)
    tgmed.add_construction_items(pk)
    tgmed.add_tool_items(pk)
    tgmed.add_gun_items(pk)
    tgmed.add_janitor_items(pk)
