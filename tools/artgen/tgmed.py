"""Sprites for the tg medical/gore/chemistry pass: gibs, blood drips, drag trails and bloody
footprints, severed limbs and organs, the tg medical stacks (sutures, mesh, bone gel,
surgical tape, splints, bonesetter), blood packs, pills, patches, bottles, droppers, and
the ChemMaster and chem heater. tgport.add_objects/add_items call in here."""
import math

import numpy as np

from common import Canvas, ellipse_mask, hexc, ramp, rng_for, rrect_mask, sel_outline, shade, shaded_fill

BLOOD = ("#4a0a12", "#7a121e", "#a81e2a", "#c8323a")
FLESH = ("#6a2a2a", "#a84a4a", "#d87a6a", "#e8a898")


def _S(w=32, h=32):
    from objects import Sprite
    return Sprite(w, h)


def _fin(cv):
    from items import _fin as f
    return f(cv)


# ------------------------------------------------------------------ gore
def gibs(v):
    cv = Canvas()
    rng = rng_for(f"gibs{v}")
    pb = [hexc(h) for h in BLOOD]
    pf = [hexc(h) for h in FLESH]
    m = np.zeros((32, 32), bool)
    cx, cy = rng.randint(12, 20), rng.randint(14, 20)
    for _ in range(5):
        m |= ellipse_mask(32, 32, cx + rng.randint(-6, 6), cy + rng.randint(-4, 4), rng.uniform(2, 5), rng.uniform(1.5, 3))
    for y, x in zip(*np.nonzero(m)):
        cv.px(x, y, pb[1])
    for _ in range(3 + v):
        ox, oy = cx + rng.randint(-8, 8), cy + rng.randint(-6, 6)
        r = rng.uniform(1.2, 2.6)
        cm = ellipse_mask(32, 32, ox, oy, r, r * 0.8)
        for y, x in zip(*np.nonzero(cm)):
            cv.px(x, y, pf[1] if (x + y) % 3 else pf[2])
        cv.px(ox - 1, oy - 1, pf[3])
    if v % 2 == 0:
        for t in range(10):
            cv.px(cx - 6 + t, cy + int(2 * math.sin(t * 0.9)), pf[2])
    cv.px(cx + 3, cy - 4, hexc("#e8e0c8"))
    cv.px(cx + 4, cy - 4, hexc("#e8e0c8"))
    sel_outline(cv, color=pb[0])
    return cv


def blood_drip(v):
    cv = Canvas()
    rng = rng_for(f"drip{v}")
    pb = [hexc(h) for h in BLOOD]
    for _ in range(2 + v):
        x, y = rng.randint(9, 22), rng.randint(9, 22)
        cv.px(x, y, pb[2])
        cv.px(x + 1, y, pb[1])
        if rng.random() < 0.5:
            cv.px(x, y + 1, pb[1])
    return cv


def blood_trail(horizontal):
    cv = Canvas()
    pb = [hexc(h) for h in BLOOD]
    for i in range(32):
        for w in (-2, -1, 0, 1, 2):
            if abs(w) == 2 and (i * 7) % 5 < 3:
                continue
            x, y = (i, 16 + w) if horizontal else (16 + w, i)
            cv.px(x, y, pb[1] if abs(w) < 2 else pb[0])
        if (i * 13) % 7 == 0:
            x, y = (i, 16) if horizontal else (16, i)
            cv.px(x, y, pb[2])
    return cv


def bloody_prints(d):
    cv = Canvas()
    pb = hexc("#7a121e", 0.85)
    for (ox, oy) in ((11, 10), (18, 19)):
        if d in "ns":
            cv.rect(ox, oy, ox + 2, oy + 4, pb)
        else:
            cv.rect(oy - 4, ox + 2, oy, ox + 4, pb)
    return cv


# ------------------------------------------------------------------ chem machines
def chem_master():
    from objects import box3d, contact_shadow, lamp, screen
    sp = _S(32, 40)
    cv = sp.cv
    contact_shadow(cv, 4, 27, 38)
    box3d(cv, 4, 8, 27, 37, 4, "#c8d0dc", 0.3)
    screen(sp, 7, 13, 24, 21, "#6ae8a8", rng_for("chemmaster"), "text")
    cv.rect(9, 26, 14, 33, hexc("#2a2e38"))
    cv.rect(10, 28, 13, 32, hexc("#cfe8f5", 0.6))
    cv.rect(18, 27, 24, 31, hexc("#3a3e48"))
    for x in (19, 21, 23):
        cv.px(x, 29, hexc("#e84a4a"))
    lamp(sp, 25, 11, "#5aff7a")
    return sp


def chem_heater(on=False):
    from objects import box3d, contact_shadow, lamp
    sp = _S()
    cv = sp.cv
    contact_shadow(cv, 6, 25, 30)
    box3d(cv, 6, 14, 25, 29, 3, "#8a93a3", 0.35)
    for x in range(9, 23):
        if on:
            sp.g(x, 13, hexc("#ff6a2a"))
        else:
            cv.px(x, 13, hexc("#4a4e58"))
    cv.rect(12, 7, 19, 12, hexc("#cfe8f5", 0.55))
    lamp(sp, 22, 24, "#ff6a2a" if on else "#5aff7a")
    return sp


def add_objects(pk):
    import gore
    gore.add_objects(pk)
    for d in "nesw":
        pk.add(f"bloodprints_{d}", bloody_prints(d))
    pk.add("chem_master", chem_master())
    pk.add("chem_heater", chem_heater(False))
    pk.add("chem_heater_on", chem_heater(True))


# ------------------------------------------------------------------ body parts, organs, medical items
def limb(kind, skin="#d8a888"):
    cv = Canvas()
    ps = ramp(skin, 5, 0.35)
    pb = [hexc(h) for h in BLOOD]
    if kind == "arm":
        for t in range(14):
            x, y = 9 + t, 20 - t // 2
            for w in range(3):
                cv.px(x, y + w, ps[1 + w])
        for y, x in zip(*np.nonzero(ellipse_mask(32, 32, 23, 12, 2.5, 2.5))):
            cv.px(x, y, ps[2])
        for w in range(3):
            cv.px(8, 20 + w, pb[2])
    elif kind == "leg":
        for t in range(15):
            for w in range(4):
                cv.px(14 + w, 8 + t, ps[1 + min(w, 3)])
        cv.rect(14, 23, 21, 25, hexc("#2a2a30"))
        for w in range(4):
            cv.px(14 + w, 7, pb[2])
    elif kind == "head":
        for y, x in zip(*np.nonzero(ellipse_mask(32, 32, 16, 15, 6, 7))):
            cv.px(x, y, ps[2] if x > 14 else ps[1])
        cv.px(14, 14, hexc("#1a1a1a"))
        cv.px(18, 14, hexc("#1a1a1a"))
        cv.hline(15, 17, 18, hexc("#6a3a3a"))
        for x in range(12, 21):
            cv.px(x, 22, pb[2])
        for x in range(11, 22):
            cv.px(x, 8, hexc("#3a2a1a"))
    return _fin(cv)


def organ(kind):
    cv = Canvas()
    if kind == "heart":
        m = ellipse_mask(32, 32, 14, 15, 4, 4) | ellipse_mask(32, 32, 18, 15, 4, 4)
        for y in range(16, 23):
            for x in range(10 + (y - 16), 23 - (y - 16)):
                m[y, x] = True
        shaded_fill(cv, m, "#b82a3a", 0.4)
        cv.px(16, 10, hexc("#6a3aa8"))
        cv.px(16, 9, hexc("#6a3aa8"))
    elif kind == "brain":
        shaded_fill(cv, ellipse_mask(32, 32, 16, 16, 8, 6), "#e8a8b8", 0.35)
        for x in range(9, 24, 3):
            cv.vline(x, 12, 20, hexc("#b87888"))
        cv.vline(16, 10, 22, hexc("#a86878"))
    elif kind == "lungs":
        for cx in (12, 20):
            shaded_fill(cv, ellipse_mask(32, 32, cx, 17, 4, 6), "#e88898", 0.35)
        cv.vline(16, 8, 14, hexc("#c8c8d8"))
    elif kind == "liver":
        shaded_fill(cv, ellipse_mask(32, 32, 16, 16, 8, 4), "#7a2a1a", 0.35)
    elif kind == "stomach":
        # tg stomach: a pink J-shaped sac
        m = ellipse_mask(32, 32, 17, 17, 7, 5) | ellipse_mask(32, 32, 12, 12, 3, 4)
        shaded_fill(cv, m, "#d88a8a", 0.35)
        cv.px(11, 8, hexc("#b86a6a"))
        cv.px(11, 7, hexc("#b86a6a"))
        for x in range(13, 22):
            cv.px(x, 19, hexc("#b86a6a"))
    elif kind == "appendix":
        for t in range(10):
            x = 13 + t // 2
            y = 10 + t
            cv.px(x, y, hexc("#c87a6a"))
            cv.px(x + 1, y, hexc("#e89a8a"))
            cv.px(x + 2, y, hexc("#a85a4a"))
        shaded_fill(cv, ellipse_mask(32, 32, 19, 21, 2, 2), "#c87a6a", 0.35)
    elif kind == "appendix_inflamed":
        for t in range(10):
            x = 13 + t // 2
            y = 10 + t
            cv.px(x, y, hexc("#a8403a"))
            cv.px(x + 1, y, hexc("#d8604a"))
            cv.px(x + 2, y, hexc("#882a2a"))
        shaded_fill(cv, ellipse_mask(32, 32, 19, 21, 3, 3), "#b8483a", 0.35)
        cv.px(19, 21, hexc("#e8d84a"))
    elif kind == "eyes":
        for cx in (12, 20):
            shaded_fill(cv, ellipse_mask(32, 32, cx, 16, 3, 3), "#f0f0f0", 0.2)
            cv.px(cx, 16, hexc("#3a6ad8"))
    return _fin(cv)


def med_stack(kind):
    cv = Canvas()
    if kind == "suture":
        shaded_fill(cv, rrect_mask(32, 32, 10, 11, 21, 21, 2), "#e8eef4", 0.3)
        cv.rect(12, 13, 19, 19, hexc("#4ab8d8"))
        for t in range(8):
            cv.px(12 + t, 16 + int(1.5 * math.sin(t)), hexc("#1a3a5a"))
    elif kind == "mesh":
        shaded_fill(cv, rrect_mask(32, 32, 10, 11, 21, 21, 2), "#e8eef4", 0.3)
        for x in range(12, 20, 2):
            cv.vline(x, 13, 19, hexc("#6ae88a"))
        for y in range(13, 20, 2):
            cv.hline(12, 19, y, hexc("#6ae88a"))
    elif kind == "bone_gel":
        shaded_fill(cv, rrect_mask(32, 32, 12, 9, 19, 24, 2), "#e8e0c8", 0.35)
        cv.rect(12, 7, 19, 9, hexc("#6a7486"))
        cv.rect(13, 14, 18, 19, hexc("#d8a53a"))
    elif kind == "surgical_tape":
        shaded_fill(cv, ellipse_mask(32, 32, 16, 16, 7, 7), "#e8eef4", 0.3)
        for y, x in zip(*np.nonzero(ellipse_mask(32, 32, 16, 16, 3, 3))):
            cv.px(x, y, hexc("#4a5060"))
    elif kind == "splint":
        for x in (12, 19):
            cv.rect(x, 6, x + 1, 26, hexc("#b8894a"))
        for y in (10, 16, 22):
            cv.hline(11, 21, y, hexc("#e8eef4"))
    elif kind == "bonesetter":
        for t in range(12):
            cv.px(10 + t, 9 + t, hexc("#9aa3b3"))
            cv.px(22 - t, 9 + t, hexc("#9aa3b3"))
        cv.rect(8, 20, 11, 24, hexc("#4ab8d8"))
        cv.rect(21, 20, 24, 24, hexc("#4ab8d8"))
    return _fin(cv)


def blood_pack(full):
    cv = Canvas()
    shaded_fill(cv, rrect_mask(32, 32, 10, 9, 21, 24, 3), "#e8eef4", 0.2)
    if full:
        shaded_fill(cv, rrect_mask(32, 32, 11, 12, 20, 23, 2), "#b8202a", 0.35)
    cv.rect(15, 5, 16, 9, hexc("#9aa3b3"))
    cv.rect(12, 14, 19, 16, hexc("#e8eef4"))
    return _fin(cv)


def pill(col="#e8e8e8"):
    cv = Canvas()
    shaded_fill(cv, ellipse_mask(32, 32, 16, 16, 4, 3), col, 0.35)
    cv.vline(16, 14, 18, shade(hexc(col), -0.3))
    return _fin(cv)


def patch(col="#e8e8e8"):
    cv = Canvas()
    shaded_fill(cv, rrect_mask(32, 32, 10, 12, 21, 20, 2), "#e8d8c0", 0.25)
    cv.rect(13, 14, 18, 18, hexc(col))
    return _fin(cv)


def bottle(col=None):
    cv = Canvas()
    for y, x in zip(*np.nonzero(rrect_mask(32, 32, 12, 12, 19, 24, 2))):
        cv.px(x, y, hexc("#cfe8f5", 0.55))
    if col:
        for y in range(17, 24):
            cv.hline(13, 18, y, hexc(col, 0.9))
    cv.rect(14, 8, 17, 11, hexc("#cfe8f5", 0.7))
    cv.rect(13, 7, 18, 8, hexc("#3a3e48"))
    return _fin(cv)


def dropper():
    cv = Canvas()
    for t in range(10):
        cv.px(11 + t, 21 - t, hexc("#cfe8f5"))
        cv.px(12 + t, 21 - t, hexc("#cfe8f5", 0.6))
    cv.rect(21, 8, 24, 11, hexc("#d83a3a"))
    return _fin(cv)


def add_items(pk):
    import gore
    gore.add_items(pk)
    for k in ("heart", "brain", "lungs", "liver", "eyes", "stomach", "appendix", "appendix_inflamed"):
        pk.add(f"organ_{k}", organ(k))
    for k in ("suture", "mesh", "bone_gel", "surgical_tape", "splint", "bonesetter"):
        pk.add(k, med_stack(k))
    pk.add("blood_pack", blood_pack(False))
    pk.add("blood_pack_full", blood_pack(True))
    pk.add("pill", pill())
    pk.add("patch", patch())
    pk.add("bottle", bottle())
    pk.add("bottle_filled", bottle("#4ab8d8"))
    pk.add("dropper", dropper())


# ------------------------------------------------------------------ construction (tg frames, wallframes, floor tiles)
def frame(kind, state):
    sp = _S()
    cv = sp.cv
    p = ramp("#7a8494", 5, 0.4)
    top = 8 if kind == "machine" else 12
    for x in (6, 7, 24, 25):
        cv.vline(x, top, 29, p[2 if x % 2 == 0 else 1])
    for y in (top, top + 1, 28, 29):
        cv.hline(6, 25, y, p[3 if y % 2 == 0 else 1])
    if kind == "computer":
        cv.rect(8, top + 2, 23, top + 3, p[2])
    if state >= 2:
        for t in range(14):
            cv.px(8 + t, 24 - (t % 5), hexc("#d83a3a"))
            cv.px(8 + t, 26 - (t % 3), hexc("#3a6ad8"))
    if state >= 3:
        cv.rect(11, top + 4, 20, top + 10, hexc("#3a9a4a"))
        for x in range(12, 20, 2):
            cv.vline(x, top + 5, top + 9, hexc("#d8b84a"))
    if state == 0:
        cv.hline(6, 25, 30, hexc("#16141d", 0.4))
    return sp


def add_construction_objects(pk):
    for k in ("machine", "computer"):
        for s in range(4):
            pk.add(f"{k}_frame_{s}", frame(k, s))


def wallframe():
    cv = Canvas()
    shaded_fill(cv, rrect_mask(32, 32, 8, 10, 23, 22, 1), "#aeb6c4", 0.35)
    cv.rect(10, 12, 21, 20, hexc("#4a5060"))
    for x in (11, 20):
        cv.px(x, 13, hexc("#d8d8d8"))
        cv.px(x, 19, hexc("#d8d8d8"))
    return _fin(cv)


def floor_tile():
    cv = Canvas()
    for i in range(3):
        m = rrect_mask(32, 32, 8, 15 - i * 2, 23, 21 - i * 2, 0)
        shaded_fill(cv, m, "#8a93a3", 0.3)
        cv.px(10, 17 - i * 2, hexc("#b8c0cc"))
        cv.px(21, 17 - i * 2, hexc("#b8c0cc"))
    return _fin(cv)


def add_construction_items(pk):
    pk.add("wallframe", wallframe())
    pk.add("floor_tile", floor_tile())


# ------------------------------------------------------------------ RCD / RPD
def rcd(pipe=False):
    from items import Sprite
    sp = Sprite()
    cv = sp.cv
    body = rrect_mask(32, 32, 7, 11, 22, 23, 2)
    shaded_fill(cv, body, "#e8c83a" if not pipe else "#4a8ad8", 0.35)
    cv.rect(18, 13, 26, 17, hexc("#6a7486"))
    cv.rect(24, 12, 27, 18, hexc("#4a5060"))
    cv.rect(9, 18, 14, 25, hexc("#3a3e48"))
    cv.rect(10, 13, 16, 16, hexc("#0b1a22"))
    _fin(cv)
    for x in range(11, 16):
        sp.g(x, 14, hexc("#5aff9a" if not pipe else "#6ad8ff"))
    return sp


def rcd_ammo():
    cv = Canvas()
    shaded_fill(cv, rrect_mask(32, 32, 10, 10, 21, 23, 2), "#6a7486", 0.35)
    cv.rect(12, 13, 19, 20, hexc("#e8c83a"))
    cv.hline(12, 19, 16, hexc("#3a3e48"))
    return _fin(cv)


def add_tool_items(pk):
    pk.add("rcd", rcd())
    pk.add("rpd", rcd(True))
    pk.add("rcd_ammo", rcd_ammo())


# ------------------------------------------------------------------ ballistics (tg /obj/item/gun/ballistic)
def revolver():
    from items import _box
    cv = Canvas()
    _box(cv, 11, 12, 27, 15, "#5a5f6a", 1)
    shaded_fill(cv, ellipse_mask(32, 32, 14, 16, 3, 3), "#6a7486", 0.4)
    cv.rect(8, 16, 12, 25, hexc("#6a4a2a"))
    cv.rect(9, 17, 11, 24, hexc("#8a6a3a"))
    cv.px(26, 12, hexc("#c8ccd4"))
    return _fin(cv)


def shotgun():
    from items import _box
    cv = Canvas()
    _box(cv, 4, 13, 29, 15, "#4a4e58", 1)
    cv.rect(12, 16, 21, 17, hexc("#3a3e48"))
    cv.rect(3, 15, 10, 19, hexc("#6a4a2a"))
    cv.rect(14, 16, 19, 18, hexc("#1a1a20"))
    cv.px(29, 13, hexc("#c8ccd4"))
    return _fin(cv)


def ammo_box(col, label):
    """An open box of rounds: brass cases and bullet tips showing over the rim."""
    cv = Canvas()
    for i, x in enumerate(range(11, 21, 2)):
        cv.rect(x, 9, x + 1, 13, hexc("#d8b84a"))
        cv.px(x, 9, hexc("#8a5a3a") if label == "#d84a4a" else hexc("#4a8ad8"))
        cv.px(x + 1, 9, hexc("#6a4a2a") if label == "#d84a4a" else hexc("#3a6ab8"))
        cv.px(x + 1, 12, hexc("#a88a3a"))
    shaded_fill(cv, rrect_mask(32, 32, 9, 13, 22, 24, 1), col, 0.35)
    cv.rect(11, 16, 20, 20, hexc(label))
    cv.hline(12, 19, 18, hexc("#f0f0f0"))
    cv.hline(9, 22, 13, shade(hexc(col), 0.3))
    return _fin(cv)


def shell(col):
    cv = Canvas()
    for i, (x, y) in enumerate(((11, 14), (15, 16), (19, 13))):
        cv.rect(x, y, x + 2, y + 6, hexc(col))
        cv.rect(x, y + 5, x + 2, y + 6, hexc("#d8b84a"))
    return _fin(cv)


def add_gun_items(pk):
    pk.add("revolver", revolver())
    pk.add("shotgun", shotgun())
    pk.add("ammo_38", ammo_box("#5a5f6a", "#d84a4a"))
    pk.add("ammo_38_rubber", ammo_box("#5a5f6a", "#4a8ad8"))
    pk.add("shell_beanbag", shell("#4ab84a"))
    pk.add("shell_buckshot", shell("#d83a3a"))
    pk.add("shell_slug", shell("#3a3e48"))


# ------------------------------------------------------------------ atmos: HE fins and the igniter
def he_fins():
    from objects import Sprite
    sp = Sprite()
    cv = sp.cv
    p = ramp("#b8704a", 5, 0.4)
    for x in range(6, 27, 3):
        cv.vline(x, 11, 21, p[3])
        cv.vline(x + 1, 11, 21, p[1])
    cv.hline(5, 27, 16, p[2])
    return sp


def igniter(on):
    from objects import Sprite, lamp
    sp = Sprite()
    cv = sp.cv
    shaded_fill(cv, ellipse_mask(32, 32, 16, 22, 6, 3), "#6a7486", 0.35)
    cv.rect(15, 15, 17, 21, hexc("#9aa3b3"))
    lamp(sp, 16, 14, "#ff9a3a" if on else "#5a5f6a")
    return sp


def add_atmos_objects(pk):
    pk.add("he_fins", he_fins())
    pk.add("igniter", igniter(False))
    pk.add("igniter_on", igniter(True))


def wet_floor_sign():
    cv = Canvas()
    y = ramp("#f0d030", 5, 0.4)
    for r in range(14):
        half = r // 2 + 1
        for x in range(16 - half, 16 + half + 1):
            cv.px(x, 9 + r, y[3] if x < 16 else y[2])
    cv.vline(16, 12, 18, hexc("#1a1a20"))
    cv.px(16, 20, hexc("#1a1a20"))
    cv.hline(9, 23, 23, hexc("#a88a20"))
    return _fin(cv)


def add_janitor_items(pk):
    pk.add("wet_floor_sign", wet_floor_sign())
