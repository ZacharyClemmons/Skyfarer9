"""Station objects, second generation: wall-mounted fixtures, drawn on the wall's front face
(see objects_v2.py)."""
from common import hexc, mix, shade
from objects_v2 import sheen, REDRAWN, E, H, R, _sp, cabinet, done, door, fill, lamp, obj, rod, screen
from px import shade_mask, sphere_height


def plate(cv, x0, y0, x1, y1, col, mat="metal"):
    """A wall box: a thin lit top lip and a bevelled face, with a hard shadow cast down the wall."""
    for x in range(x0 + 1, x1 + 2):
        cv.px(x, y1 + 1, (0.02, 0.02, 0.06, 0.45))
    for y in range(y0 + 1, y1 + 1):
        cv.px(x1 + 1, y, (0.02, 0.02, 0.06, 0.3))
    return cabinet(cv, x0, y0, x1, y1, 1, col, mat, bevel=1.2)


@obj("apc")
def apc():
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 7, 5, 24, 21, "#9aa3b3")
    # hazard strip and the cover's latch
    for x in range(8, 24):
        cv.px(x, 7, H("#e8c03a") if (x // 2) % 2 == 0 else H("#26242c"))
    screen(sp, 10, 10, 20, 14, "#5aff9a", "bars", "apc")
    # channel lights: equipment, lighting, environment, and the charge lamp
    for i, c in enumerate(("#5aff7a", "#5aff7a", "#5aff7a")):
        lamp(sp, 10 + i * 3, 17, c)
    lamp(sp, 20, 17, "#ffcc4a")
    cv.rect(22, 11, 22, 15, fp[0])
    cv.hline(9, 22, 20, fp[0])
    return done(sp)


@obj("air_alarm")
def air_alarm():
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 9, 6, 22, 19, "#c9d0da")
    screen(sp, 11, 9, 20, 14, "#5ad0ff", "graph", "aa")
    lamp(sp, 11, 16, "#5aff7a")
    for x in (14, 16, 18, 20):
        cv.px(x, 16, fp[0])
    return done(sp)


def fire_alarm(state):
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 11, 7, 20, 18, "#c83a3a", "paint")
    # the pull handle under its glass
    cv.rect(13, 10, 18, 15, H("#8a1a22"))
    cv.rect(14, 12, 17, 13, H("#f0e8e0"))
    cv.px(13, 10, H("#ffb0a8"))
    if state == "on":
        for (x, y) in ((15, 8), (16, 8)):
            sp.g(x, y, H("#ff6a4a"))
        lamp(sp, 19, 17, "#ff3a2a")
    else:
        lamp(sp, 15, 8, "#ff6a4a" if state == "base" else "#5aff7a")
        lamp(sp, 16, 8, "#ff6a4a" if state == "base" else "#5aff7a")
    return done(sp)


REDRAWN["fire_alarm"] = lambda: fire_alarm("base")
REDRAWN["fire_alarm_idle"] = lambda: fire_alarm("idle")
REDRAWN["fire_alarm_on"] = lambda: fire_alarm("on")


@obj("intercom")
def intercom():
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 11, 7, 20, 18, "#7a8494")
    # speaker grille
    g = E(cv, 15.5, 13, 3.4, 3.4)
    fill(cv, g, H("#2a2e38"))
    for (x, y) in ((14, 12), (16, 12), (15, 13), (17, 13), (14, 14), (16, 14), (15, 11), (15, 15)):
        cv.px(x, y, H("#4a505e"))
    lamp(sp, 19, 9, "#5aff7a")
    cv.px(12, 17, H("#c8d0dc"))
    cv.px(13, 17, H("#c8d0dc"))
    return done(sp)


@obj("status_display")
def status_display():
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 3, 5, 28, 21, "#4a5262")
    for y in range(8, 19):
        for x in range(5, 27):
            cv.px(x, y, H("#08141a"))
            sp.glow.px(x, y, hexc("#0c2a36"))
    sp.has_glow = True
    for x in range(5, 27):
        sp.g(x, 8, H("#1a4a5a"))
    cv.hline(5, 26, 19, fp[-1])
    lamp(sp, 26, 20, "#5aff7a")
    return done(sp)


def light(on, broken=False):
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 5, 8, 26, 13, "#aeb6c4")
    # the tube behind its diffuser
    for x in range(7, 25):
        if broken:
            if x % 5 in (1, 2):
                cv.px(x, 11, H("#c8d0dc"))
                cv.px(x, 12, H("#5a5f6a"))
            else:
                cv.px(x, 11, H("#3a3f4a"))
        elif on:
            sp.g(x, 11, H("#ffffff"))
            sp.g(x, 12, H("#fff4d8"))
        else:
            cv.px(x, 11, H("#a0a6b0"))
            cv.px(x, 12, H("#7a808c"))
    for x in (6, 25):
        cv.vline(x, 10, 12, fp[0])
    return done(sp)


REDRAWN["light_on"] = lambda: light(True)
REDRAWN["light_off"] = lambda: light(False)
REDRAWN["light_broken"] = lambda: light(True, True)


def ext_cabinet(full):
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 10, 4, 21, 22, "#b0b8c4")
    cv.rect(12, 7, 19, 20, H("#1e2430"))
    if full:
        body = R(cv, 13, 10, 18, 20, 2)
        pal = shade_mask(cv, body, "#d0342e", "paint", bevel=2)
        cv.rect(15, 7, 16, 9, H("#26242c"))
        cv.hline(13, 16, 8, H("#26242c"))
        cv.rect(14, 14, 17, 16, H("#e8e0d0"))
    # the glass door with a glint
    for y in range(7, 21):
        sheen(cv, 12 + (y - 7) // 3, y, 0.22)
    cv.vline(19, 12, 15, H("#6b7486"))
    return done(sp)


REDRAWN["extinguisher_cabinet"] = lambda: ext_cabinet(True)
REDRAWN["extinguisher_cabinet_empty"] = lambda: ext_cabinet(False)


@obj("emergency_light")
def emergency_light():
    sp = _sp()
    cv = sp.cv
    plate(cv, 12, 8, 19, 13, "#4a4f5c")
    dome = E(cv, 15.5, 10.5, 2.6, 2)
    fill(cv, dome, H("#7a1a1a"))
    for (x, y) in ((15, 10), (16, 10), (15, 11), (16, 11)):
        sp.g(x, y, H("#ff3a2a"))
    sp.g(15, 9, H("#ffb0a0"))
    return done(sp)
