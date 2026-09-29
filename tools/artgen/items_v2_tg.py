"""Item icons, second generation: tg items this game didn't have before (see items_v2.py)."""
from common import hexc, mix, shade
from items_v2 import NEW, W, _cv, box, dots, glint, glowing, new_item, rod
from px import finish, poly_mask, rect_m, shade_mask


def _t_scanner(on):
    """tg's T-ray scanner: a handheld with an emitter snout, a scan screen and a grip."""
    cv = _cv()
    # grip
    box(cv, 12, 20, 19, 27, "#3a3f4a", "rubber", 2, 1.5)
    for y in (22, 24):
        cv.hline(13, 18, y, hexc("#26242c"))
    # body
    pal, _ = box(cv, 9, 8, 22, 21, "#c8a83a", "plastic", 2, 2)
    # emitter snout on top
    box(cv, 13, 4, 18, 8, "#5a6272", "metal", 1, 1)
    cv.hline(14, 17, 4, hexc("#9aa3b3"))
    # the screen
    box(cv, 11, 10, 20, 16, "#101a1e", "glass", 1, 1)
    pts = []
    if on:
        for (x, y) in ((12, 13), (13, 13), (14, 12), (15, 13), (16, 14), (17, 13), (18, 13), (19, 12)):
            pts.append((x, y, "#5affe8"))
        pts.append((20, 19, "#5aff7a"))
    else:
        cv.hline(12, 19, 13, hexc("#1f3a3a"))
        cv.px(20, 19, hexc("#3a2a2a"))
    # a button and the label stripe
    dots(cv, ((11, 18), (12, 18)), "#3a3f4a")
    cv.hline(10, 21, 21, pal[0])
    finish(cv)
    return glowing(cv, pts) if pts else cv


NEW["t_scanner"] = lambda: _t_scanner(False)
NEW["t_scanner_on"] = lambda: _t_scanner(True)
