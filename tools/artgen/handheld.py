"""In-hand sprites, tg style: every item gets held views (facing south, north and east; west
is the east view mirrored) drawn at a size that suits it and turned the way it's actually
held, with its grip on the hand.

Each view is a 32x32 canvas whose centre (16, 16) is the grip: the game puts that point on
the doll's hand. Views are made from the item's own icon: its long axis and grip are found
from the pixels (icons are drawn handle-lower-left to head-upper-right, guns pointing right
with the grip low on the left), then it's scaled and rotated with a rotsprite-style pass
(EPX upscale, rotate, supersample back down) so pixel lines stay clean, and re-outlined.

Holding styles:
  tool    screwdrivers, wrenches, knives, batons: head up and a little outward, forward
          and up when side-on
  long    spears, axes, mops, bats, pickaxes: big, held low on the shaft, raised
  pistol  guns, welders, flashlights, RCDs: pointing where you face (down when facing south,
          up when facing north, forward side-on)
  rifle   shotguns: like a pistol but longer, held at the stock
  carry   toolboxes, medkits, buckets: hang from the hand by their handle, upright
  shield  riot shields: big and upright in front of the arm
  small   everything else (cans, food, beakers, sheets...): upright in the palm
"""
import math

import numpy as np

from common import Canvas, sel_outline

LONG = {"spear", "fireaxe", "mop", "baseball_bat", "pickaxe"}
PISTOL = {"laser_gun", "disabler", "egun_stun", "egun_kill", "revolver", "welder", "welder_on", "rcd", "rpd",
          "flashlight", "flashlight_on", "holofan", "circular_saw", "extinguisher_mini", "pepperspray", "spray_bottle", "defib"}
RIFLE = {"shotgun"}
CARRY = {"toolbox_red", "toolbox_blue", "toolbox_yellow", "medkit", "medkit_burn", "medkit_toxin", "medkit_o2", "bucket",
         "extinguisher", "tank_o2", "tank_air", "tank_plasma", "tank_fuel", "blood_pack", "blood_pack_full"}
SHIELD = {"riot_shield"}
TOOL = {"wrench", "crowbar", "screwdriver", "wirecutters", "knife_kitchen", "knife_cleaver", "knife_survival",
        "scalpel", "hemostat", "retractor", "cautery", "baton", "pen", "shiv", "dropper", "bonesetter", "syringe", "medipen",
        "cigarette", "cigarette_lit", "glowstick"}

# How big each item is in the hand, in pixels along its long side, so held things are sized
# like the real object next to the character (about 26 px tall) whatever size the floor icon
# is drawn at. Class defaults, then per-item overrides.
HELD_LEN = {"tool": 10.0, "long": 17.0, "pistol": 10.0, "rifle": 17.0, "carry": 10.0, "shield": 15.0, "small": 8.0}
HELD_SIZE = {
    # tools
    "screwdriver": 8.5, "wirecutters": 9, "wrench": 10, "crowbar": 12.5, "pen": 6.5, "cigarette": 5, "cigarette_lit": 5,
    "glowstick": 7, "syringe": 7.5, "medipen": 7, "dropper": 6.5, "scalpel": 8, "hemostat": 8.5, "retractor": 9, "cautery": 8,
    "bonesetter": 9, "baton": 13, "shiv": 8.5, "knife_kitchen": 10, "knife_cleaver": 9.5, "knife_survival": 10,
    # long things
    "spear": 21, "fireaxe": 17, "mop": 18, "baseball_bat": 15, "pickaxe": 14,
    # guns and gadgets held like one
    "revolver": 9, "disabler": 9.5, "laser_gun": 10, "egun_stun": 10.5, "egun_kill": 10.5, "welder": 10, "welder_on": 10,
    "flashlight": 8, "flashlight_on": 8, "holofan": 8.5, "rcd": 11, "rpd": 11, "circular_saw": 10, "defib": 10,
    "extinguisher_mini": 7, "pepperspray": 6, "spray_bottle": 7.5, "shotgun": 18,
    # carried by the handle
    "toolbox_red": 11, "toolbox_blue": 11, "toolbox_yellow": 11, "medkit": 9.5, "medkit_burn": 9.5, "medkit_toxin": 9.5,
    "medkit_o2": 9.5, "bucket": 8.5, "extinguisher": 11, "tank_o2": 11, "tank_air": 11, "tank_plasma": 11, "tank_fuel": 11,
    "blood_pack": 7.5, "blood_pack_full": 7.5, "riot_shield": 15,
    # small things in the palm
    "pill": 3.5, "patch": 4.5, "id_gen": 6, "paper": 7, "lighter": 5, "lighter_on": 5, "soap": 6, "cig_pack": 5.5,
    "food_egg": 4.5, "food_tomato": 5.5, "food_berries": 5.5, "food_banana": 7, "food_potato": 6, "drink_soda": 5.5,
    "drink_water": 6.5, "drink_booze": 8, "drink_cocoa": 6, "drink_coffee": 6, "beaker": 6.5, "beaker_filled": 6.5,
    "bottle": 5.5, "bottle_filled": 5.5, "pill_bottle": 5.5, "sheet_metal": 9, "sheet_glass": 9, "sheet_rglass": 9,
    "sheet_plasteel": 9, "sheet_wood": 9, "sheet_plasma": 9, "rods": 11, "floor_tile": 8, "light_tube": 10, "cable_coil": 7,
    "multitool": 6.5, "health_analyzer": 6.5, "gas_analyzer": 6.5, "headset": 6, "sunglasses": 7, "gas_mask": 7,
    "welding_helmet": 8, "glass_shard": 6, "glass_shard_medium": 5, "glass_shard_small": 4, "ice_chunk": 7,
    "ore_iron": 6.5, "ore_plasma": 6.5, "ore_cryo": 6.5, "ore_gold": 6.5, "organ_brain": 7, "organ_heart": 6,
    "limb_arm": 11, "limb_leg": 13, "limb_head": 8, "circuit_board": 7, "flashbang": 6, "smoke_grenade": 6,
    "flashbang_active": 6, "smoke_grenade_active": 6, "molotov": 8, "molotov_lit": 8, "handcuffs": 6.5, "cable_cuffs": 6.5,
}
for _k in ("cmd", "eng", "med", "sec", "sci", "srv", "cargo", "cap"):
    HELD_SIZE["id_" + _k] = 6
for _k in ("gen", "cmd", "eng", "med", "sec", "sci", "srv", "cargo"):
    HELD_SIZE["coat_" + _k] = 10
# where the grip is along the item, from the butt (0) to the tip (1)
GRIP = {"tool": 0.14, "long": 0.28, "pistol": 0.28, "rifle": 0.3, "carry": 0.5, "shield": 0.5, "small": 0.5}
# direction the tip points (degrees, screen space: 0 = right, -90 = up) for each view
ANGLE = {
    "tool": {"s": -68, "n": -80, "e": -38},
    "long": {"s": -76, "n": -84, "e": -58},
    "pistol": {"s": 78, "n": -80, "e": 0},
    "rifle": {"s": 80, "n": -82, "e": -4},
}


def style_of(name):
    base = name
    if base in LONG:
        return "long"
    if base in RIFLE:
        return "rifle"
    if base in PISTOL or base.startswith("egun"):
        return "pistol"
    if base in CARRY or base.startswith("toolbox") or base.startswith("medkit"):
        return "carry"
    if base in SHIELD:
        return "shield"
    if base in TOOL or base.startswith("knife"):
        return "tool"
    return "small"


def _clean(a):
    """Drop the soft floor shadow and anti-alias fuzz: keep solid pixels only."""
    a = a.copy()
    a[a[:, :, 3] < 0.6] = 0.0
    return a


def _epx(a):
    """Scale2x (EPX) on an RGBA array: doubles size, smoothing diagonals."""
    h, w = a.shape[:2]
    out = np.zeros((h * 2, w * 2, 4), a.dtype)
    key = np.round(a * 255).astype(np.int32)
    k = key[:, :, 0] << 24 | key[:, :, 1] << 16 | key[:, :, 2] << 8 | key[:, :, 3]
    pad = np.pad(k, 1, mode="edge")
    P = k
    A = pad[:-2, 1:-1]
    B = pad[1:-1, 2:]
    C = pad[1:-1, :-2]
    D = pad[2:, 1:-1]
    e0 = (C == A) & (C != D) & (A != B)
    e1 = (A == B) & (A != C) & (B != D)
    e2 = (D == C) & (D != B) & (C != A)
    e3 = (B == D) & (B != A) & (D != C)
    padA = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    An = padA[:-2, 1:-1]
    Bn = padA[1:-1, 2:]
    Cn = padA[1:-1, :-2]
    Dn = padA[2:, 1:-1]
    for (dy, dx), cond, src in (((0, 0), e0, An), ((0, 1), e1, Bn), ((1, 0), e2, Cn), ((1, 1), e3, Dn)):
        v = np.where(cond[:, :, None], src, a)
        out[dy::2, dx::2] = v
    return out


def _axis(a):
    """(butt, tip) points of the item's long axis in icon pixels."""
    ys, xs = np.nonzero(a[:, :, 3] > 0.5)
    pts = np.stack([xs + 0.5, ys + 0.5], 1)
    c = pts.mean(0)
    cov = np.cov((pts - c).T) if len(pts) > 2 else np.eye(2)
    w, v = np.linalg.eigh(cov)
    d = v[:, np.argmax(w)]
    # tip points up-right (icons are drawn handle-lower-left, head-upper-right)
    if d[0] - d[1] < 0:
        d = -d
    proj = (pts - c) @ d
    return c + d * proj.min(), c + d * proj.max(), d


def _render(a, grip, tip_dir_src, target_deg, scale, rotate=True):
    """Draw icon array `a` into a 32x32 canvas with `grip` (icon px) at (16,16), the
    item's tip direction turned to `target_deg`, at `scale`."""
    up = _epx(_epx(a))  # 4x
    F = 4.0
    src_ang = math.atan2(tip_dir_src[1], tip_dir_src[0]) if rotate else 0.0
    rot = math.radians(target_deg) - src_ang if rotate else 0.0
    cr, sr = math.cos(-rot), math.sin(-rot)
    SS = 4  # supersamples per axis
    H, W = up.shape[:2]
    offs = (np.arange(SS) + 0.5) / SS
    # every output pixel x every sub-sample, all at once
    py, px, oy, ox = np.meshgrid(np.arange(32), np.arange(32), offs, offs, indexing="ij")
    X = (px + ox - 16.0) / scale
    Y = (py + oy - 16.0) / scale
    sx = (X * cr - Y * sr) + grip[0]
    sy = (X * sr + Y * cr) + grip[1]
    ix = np.floor(sx * F).astype(int).reshape(1024, SS * SS)
    iy = np.floor(sy * F).astype(int).reshape(1024, SS * SS)
    ok = (ix >= 0) & (iy >= 0) & (ix < W) & (iy < H)
    smp = np.zeros((1024, SS * SS, 4))
    smp[ok] = up[iy[ok], ix[ok]]
    solid = smp[:, :, 3] > 0.5
    luma = smp[:, :, :3] @ np.array([0.3, 0.55, 0.15])
    inner = solid & (luma > 0.13)
    keys = np.round(smp * 255).astype(np.int64)
    k = keys[:, :, 0] * 16777216 + keys[:, :, 1] * 65536 + keys[:, :, 2] * 256 + keys[:, :, 3]
    out = np.zeros((1024, 4))
    need = solid.sum(1) >= SS * SS * 0.34
    for pi in np.nonzero(need)[0]:
        use = inner[pi] if inner[pi].sum() * 2 >= solid[pi].sum() else solid[pi]
        kk = k[pi][use]
        vals, counts = np.unique(kk, return_counts=True)
        best = vals[np.argmax(counts)]
        out[pi] = smp[pi][use][np.nonzero(kk == best)[0][0]]
    out = out.reshape(32, 32, 4)
    cv = Canvas()
    cv.a = out
    sel_outline(cv, 0.55)
    return cv


def views(name, icon):
    """{"s": Canvas, "n": Canvas, "e": Canvas} held views of the icon."""
    a = _clean(icon.a)
    if (a[:, :, 3] > 0.5).sum() < 4:
        return {}
    style = style_of(name)
    ys, xs = np.nonzero(a[:, :, 3] > 0.5)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    want = HELD_SIZE.get(name, HELD_LEN[style])
    if style in ("tool", "long"):
        butt, tip, d = _axis(a)
        length = float(np.linalg.norm(tip - butt)) + 1.0
    elif style in ("pistol", "rifle", "shield"):
        length = float(max(x1 - x0, y1 - y0) if style == "shield" else x1 - x0)
    else:
        length = float(max(x1 - x0, y1 - y0))
    sc = want / max(1.0, length)
    out = {}
    if style in ("tool", "long"):
        grip = butt + (tip - butt) * GRIP[style]
        for v in ("s", "n", "e"):
            out[v] = _render(a, grip, d, ANGLE[style][v], sc)
    elif style in ("pistol", "rifle"):
        # guns are drawn pointing right: the grip is low at the back
        grip = np.array([x0 + (x1 - x0) * GRIP[style], y0 + (y1 - y0) * 0.72])
        for v in ("s", "n", "e"):
            out[v] = _render(a, grip, (1.0, 0.0), ANGLE[style][v], sc)
    elif style == "shield":
        grip = np.array([x0 + (x1 - x0) * 0.3, (y0 + y1) / 2.0])
        for v in ("s", "n", "e"):
            out[v] = _render(a, grip, (1.0, 0.0), 0.0, sc, rotate=False)
    elif style == "carry":
        grip = np.array([(x0 + x1) / 2.0, y0 + 1.0])  # the handle, on top
        for v in ("s", "n", "e"):
            out[v] = _render(a, grip, (1.0, 0.0), 0.0, sc, rotate=False)
    else:
        grip = np.array([(x0 + x1) / 2.0, (y0 + y1) / 2.0 + (1.0 if style == "small" else 0.0)])
        for v in ("s", "n", "e"):
            out[v] = _render(a, grip, (1.0, 0.0), 0.0, sc, rotate=False)
    return out
