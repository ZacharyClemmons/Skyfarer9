"""Station objects, second generation: tg machines this game didn't have before (see objects_v2.py)."""
import numpy as np

from common import hexc, mix, shade
from objects_v2 import NEW, E, H, R, _sp, cabinet, done, fill, ground, lamp, rod, screen
from objects_v2_wall import plate


def light_switch(on):
    """tg's light switch: a small plate on the wall with a rocker and a tell-tale lamp."""
    sp = _sp()
    cv = sp.cv
    fp, _, _ = plate(cv, 12, 8, 19, 18, "#c9d0da", "plastic")
    # the rocker: the lit half is the one pressed in
    cv.rect(14, 11, 17, 16, H("#3a3f4a"))
    if on:
        cv.rect(14, 11, 17, 13, H("#e8eef4"))
        cv.hline(14, 17, 14, H("#8a93a3"))
    else:
        cv.rect(14, 14, 17, 16, H("#e8eef4"))
        cv.hline(14, 17, 13, H("#8a93a3"))
    lamp(sp, 15, 9, "#6aff9a" if on else "#ff6a4a")
    return done(sp)


NEW["light_switch_on"] = lambda: light_switch(True)
NEW["light_switch_off"] = lambda: light_switch(False)


def space_heater(mode):
    """tg's space heater: a squat box on casters, a big grille that glows when it runs, a
    little readout on top."""
    sp = _sp()
    cv = sp.cv
    ground(cv, 6, 25, 30)
    fp, tp, _ = cabinet(cv, 6, 8, 25, 28, 5, "#8a93a3", "metal")
    # carry handle
    rod(cv, 11, 6, 20, 6, 0.9, "#4a505e", "metal")
    # readout and dial on the top face
    screen(sp, 8, 9, 13, 11, {"heat": "#ff8a3a", "cool": "#5ac8ff"}.get(mode, "#6a7486"), "text", "heater" + mode)
    d = E(cv, 22, 10.5, 1.8, 1.4)
    fill(cv, d, H("#3a3f4a"))
    cv.px(22, 10, H("#c8d0dc"))
    # the grille
    cv.rect(8, 15, 23, 26, H("#1a1c22"))
    glow = {"heat": ("#ff7a2a", "#ffb05a"), "cool": ("#4ab8ff", "#9ae0ff")}.get(mode)
    for y in range(16, 26, 2):
        for x in range(9, 23):
            if glow:
                sp.g(x, y, H(glow[0] if (x + y) % 5 else glow[1]))
            else:
                cv.px(x, y, H("#4a505e"))
    for x in range(10, 23, 4):
        cv.vline(x, 15, 26, H("#6a7486"))
    # casters
    for wx in (8, 23):
        fill(cv, E(cv, wx + 0.5, 29, 1.6, 1.2), H("#26242c"))
    return done(sp)


NEW["space_heater"] = lambda: space_heater("standby")
NEW["space_heater_heat"] = lambda: space_heater("heat")
NEW["space_heater_cool"] = lambda: space_heater("cool")
