"""Skyfarer terrain: open sky, island ground for every biome, island rock, and ship decks.

Built on the same helpers as tiles.py — hue-shifted ramps, tileable value noise, selective
edges — so the new ground sits beside Artic9's snow and plating without looking pasted on.

The one genuinely new problem here is open sky. It covers 93% of a region, it must read
instantly as "nothing to stand on", and entities have to stay legible on top of it. The
answer is low contrast and low frequency: a cool blue haze with soft cloud far below, dark
enough that a lit sprite pops off it, and quiet enough that a whole screen of it is not
noisy.
"""
import numpy as np

from common import (T, Canvas, fbm, hexc, mix, quantize_ramp, ramp, rng_for,
                    shade, value_noise)
from tiles import _wall_generic, _facets, FACE_Y, N, E, S, W


# ======================================================================== open sky
SKY = ["#1b2740", "#24344f", "#2e4160", "#3a5173", "#476186", "#56729a", "#6886ae"]


def sky_tile(variant):
    """Open air seen from above: haze, with cloud a long way down."""
    rng = rng_for(f"sky{variant}")
    c = Canvas()
    pal = [hexc(h) for h in SKY]
    # base haze, very low contrast
    field = np.full((T, T), 0.42)
    field += (fbm(T, T, 300 + variant * 13, 4, 32) - 0.5) * 0.30
    # cloud far below: broad, soft, and dim, so it suggests depth without competing
    deep = fbm(T, T, 700 + variant * 29, 3, 24)
    field += np.clip(deep - 0.58, 0, 1) * 0.85
    # a few bright specks: light off something distant
    for _ in range(rng.randint(0, 2)):
        x, y = rng.randint(0, 31), rng.randint(0, 31)
        field[y, x] += 0.22
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    return c


def cloud_tile(variant):
    """A bank thick enough to fly into and lose sight of everything."""
    rng = rng_for(f"cloud{variant}")
    c = Canvas()
    pal = [hexc(h) for h in ["#3a5173", "#54708f", "#7590ab", "#9ab0c6", "#bccbdb", "#dbe5ee", "#f2f6fa"]]
    field = np.full((T, T), 0.50)
    field += (fbm(T, T, 1300 + variant * 17, 4, 20) - 0.5) * 0.85
    field += (value_noise(T, T, 3, rng.randint(0, 9999)) - 0.5) * 0.10
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    return c


# ======================================================================== island ground
def ground(name, base, variant, spread=0.34, grain=6, speckle=None, streak=0,
           tufts=0, tuft_col=None, cracks=0, pebbles=0):
    """One organic ground tile. Everything from grass to salt flat comes out of this by
    changing the palette and the decoration counts."""
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    pal = ramp(base, 7, spread)
    field = np.full((T, T), 0.50)
    field += (fbm(T, T, rng.randint(0, 9999), 3, grain * 2) - 0.5) * 0.34
    field += (value_noise(T, T, 1, rng.randint(0, 9999)) - 0.5) * 0.16
    for _ in range(streak):
        x0, y0 = rng.uniform(0, 32), rng.uniform(0, 32)
        ln = rng.randint(7, 16)
        bend = rng.uniform(-0.1, 0.1)
        for i in range(ln):
            x = int(x0 + i) % T
            y = int(y0 + i * 0.3 + bend * i * i) % T
            field[y, x] -= 0.12
            field[(y - 1) % T, x] += 0.07
    for _ in range(cracks):
        x, y = rng.randint(0, 31), rng.randint(0, 31)
        d = rng.choice([(1, 0), (0, 1), (1, 1), (1, -1)])
        for i in range(rng.randint(5, 13)):
            field[(y + d[1] * i) % T, (x + d[0] * i) % T] -= 0.30
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    if speckle:
        col, count = speckle
        for _ in range(count):
            c.px(rng.randint(0, 31), rng.randint(0, 31), hexc(col))
    # tufts: two or three pixels standing up, which is what sells grass at this size
    if tufts:
        tc = hexc(tuft_col or "#000000")
        for _ in range(tufts):
            x, y = rng.randint(1, 30), rng.randint(2, 30)
            h = rng.randint(2, 4)
            for i in range(h):
                c.px(x, y - i, mix(tc, pal[6], i / max(1, h) * 0.5))
            if rng.random() < 0.5:
                c.px(x + 1, y - 1, tc)
            c.px(x, y - h, mix(tc, hexc("#d8f0a0"), 0.35))   # sunlit tip
    # pebbles: a lit top pixel and a dark shadow beneath
    for _ in range(pebbles):
        x, y = rng.randint(1, 29), rng.randint(1, 29)
        w = rng.choice([1, 2, 2, 3])
        c.px(x, y, pal[5])
        for k in range(1, w):
            c.px(x + k, y, pal[4])
        for k in range(w + 1):
            c.px(x + k, y + 1, shade(pal[1], -0.2))
    return c


def water_tile(variant, lava=False):
    """Standing water, or something hotter."""
    rng = rng_for(f"{'lava' if lava else 'water'}{variant}")
    c = Canvas()
    if lava:
        pal = [hexc(h) for h in ["#2a1008", "#5a1c08", "#8e2f0a", "#c25213", "#e8801f", "#f7ad3c", "#ffe089"]]
    else:
        pal = [hexc(h) for h in ["#12283a", "#1b3a52", "#27506c", "#356687", "#497fa2", "#65a0bd", "#9ccddd"]]
    field = np.full((T, T), 0.42 if not lava else 0.48)
    field += (fbm(T, T, 2100 + variant * 31, 4, 16) - 0.5) * (0.6 if lava else 0.42)
    # surface ripples
    yy, xx = np.mgrid[0:T, 0:T]
    field += np.sin((xx * 0.55 + yy * 0.33) + variant) * 0.05
    if lava:
        # crust: dark plates floating on the melt
        crust = fbm(T, T, 4400 + variant * 7, 3, 12)
        field -= np.clip(crust - 0.5, 0, 1) * 1.25
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    # specular glints
    for _ in range(rng.randint(2, 5)):
        x, y = rng.randint(0, 30), rng.randint(0, 30)
        c.px(x, y, pal[6])
        c.px(x + 1, y, pal[5])
    return c


# ======================================================================== island rock
_ISLE_FACETS = None
ORE_TINT = {
    "aether": ("#4a8ad8", "#9ad0ff"),
    "sulfur": ("#c8b83a", "#f0e07a"),
    "crystal": ("#8a6ad8", "#d0b8ff"),
    "iron": ("#9a7a5a", "#c8a882"),
    "gold": ("#c8a03a", "#f0d878"),
}


def isle_rock(mask, ore=None, variant=0):
    """The stone an island is cut from: faceted, warm grey, no snow cap, so the same
    sprite works under a meadow and under a desert."""
    global _ISLE_FACETS
    if _ISLE_FACETS is None:
        import random as _r
        _ISLE_FACETS = _facets(_r.Random(8891), 11)
    rng = rng_for(f"isle{mask}{ore}{variant}")
    c = Canvas()
    rp = ramp("#6e6a62", 7, 0.5)
    open_s = not (mask & S)
    top_end = FACE_Y - 1 if open_s else T - 1
    n = fbm(T, T, 31 + mask * 5 + variant * 13, 3, 8)
    facet = _ISLE_FACETS
    for y in range(0, top_end + 1):
        for x in range(T):
            fid, border, lit = facet[y][x]
            i = int(np.clip(3 + lit * 2.2 + (n[y, x] - 0.5) * 1.3, 0, 6))
            col = rp[i]
            if border:
                col = rp[max(0, i - 2)]
            c.px(x, y, col)
    # ore veins: threads of colour following the facet borders
    if ore:
        dark, bright = ORE_TINT.get(ore, ("#8a8a8a", "#c0c0c0"))
        vn = fbm(T, T, 555 + mask, 3, 6)
        for y in range(0, top_end + 1):
            for x in range(T):
                fid, border, lit = facet[y][x]
                if border and vn[y, x] > 0.52:
                    c.px(x, y, hexc(bright if vn[y, x] > 0.68 else dark))
    # lumpy rim where a neighbour is open
    edge_n = value_noise(T, T, 4, 17 + mask)
    for y in range(0, top_end + 1):
        for x in range(T):
            d = 99
            if not mask & N:
                d = min(d, y)
            if not mask & W:
                d = min(d, x)
            if not mask & E:
                d = min(d, T - 1 - x)
            lump = 2 + edge_n[y, x] * 2.2
            if d < lump:
                c.px(x, y, (0, 0, 0, 0))
            elif d < lump + 1:
                c.px(x, y, rp[5] if (not mask & N and y < 8) else rp[1])
    # front face
    if open_s:
        c.hline(0, T - 1, FACE_Y, rp[5])
        fn = value_noise(T, T, 3, 61 + mask)
        for y in range(FACE_Y + 1, T):
            t = (y - FACE_Y) / (T - FACE_Y)
            for x in range(T):
                i = int(np.clip(4 - t * 3.4 + (fn[y, x] - 0.5) * 1.4, 0, 6))
                c.px(x, y, rp[i])
        if ore:
            dark, bright = ORE_TINT.get(ore, ("#8a8a8a", "#c0c0c0"))
            for _ in range(rng.randint(3, 7)):
                x, y = rng.randint(1, 30), rng.randint(FACE_Y + 2, T - 2)
                c.px(x, y, hexc(bright))
                c.px(x, y + 1, hexc(dark))
    return c


def thicket_tile(mask):
    """Dense brush: solid and sight-blocking, but two swings of an axe."""
    rng = rng_for(f"thicket{mask}")
    c = Canvas()
    pal = ramp("#2f4a26", 7, 0.5)
    open_s = not (mask & S)
    top_end = FACE_Y - 1 if open_s else T - 1
    n = fbm(T, T, 811 + mask, 4, 10)
    for y in range(0, top_end + 1):
        for x in range(T):
            i = int(np.clip(2 + (n[y, x] - 0.4) * 6.0, 0, 6))
            c.px(x, y, pal[i])
    # leaf clumps
    for _ in range(rng.randint(14, 22)):
        x, y = rng.randint(0, 31), rng.randint(0, max(1, top_end))
        col = pal[rng.randint(3, 6)]
        for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
            c.px(x + dx, y + dy, col)
    if open_s:
        for y in range(FACE_Y, T):
            t = (y - FACE_Y) / (T - FACE_Y)
            for x in range(T):
                i = int(np.clip(3 - t * 2.6 + (n[y % T, x] - 0.5) * 2.0, 0, 6))
                c.px(x, y, pal[i])
        # thorns along the bottom lip
        for x in range(0, T, 3):
            c.px(x, T - 1, pal[1])
    # ragged silhouette on open sides
    for y in range(0, T):
        for x in range(T):
            d = 99
            if not mask & N:
                d = min(d, y)
            if not mask & W:
                d = min(d, x)
            if not mask & E:
                d = min(d, T - 1 - x)
            if d < 1 and n[y, x] < 0.42:
                c.px(x, y, (0, 0, 0, 0))
    return c


# ======================================================================== the island's edge
def isle_edge(mask):
    """Drawn on the open-sky tile beside land: the island's broken underside hanging into
    the void. This is the sprite that sells the whole premise, so it is not subtle.

    `mask` is which of the four neighbours is land (N=1 E=2 S=4 W=8), so one set of
    sixteen covers every coastline.
    """
    c = Canvas()
    rp = ramp("#5c584f", 7, 0.6)
    rng = rng_for(f"isleedge{mask}")
    n = fbm(T, T, 2400 + mask * 31, 4, 7)
    if mask & N:
        # Land above. Its underside juts down into this tile and breaks off in a ragged
        # line, deepest in the middle of the run.
        for x in range(T):
            depth = 17 + n[0, x] * 9 + np.sin(x * 0.4 + mask) * 2.5
            for y in range(int(depth)):
                t = y / max(1.0, depth)
                i = int(np.clip(5.0 - t * 4.4 + (n[y, x] - 0.5) * 1.5, 0, 6))
                c.px(x, y, rp[i])
            # a few stalactite spurs of broken rock
            if rng.random() < 0.22:
                for k in range(rng.randint(1, 5)):
                    yy = int(depth) + k
                    if yy < T:
                        c.px(x, yy, rp[max(0, 2 - k // 2)])
        # sunlit lip along the very top, so the land above reads as sitting on this
        for x in range(T):
            c.px(x, 0, rp[6])
            c.px(x, 1, rp[5])
    for bit, is_w in ((W, True), (E, False)):
        if not (mask & bit):
            continue
        for y in range(T):
            w = 5 + n[y, 0 if is_w else T - 1] * 5
            for k in range(int(w)):
                x = k if is_w else T - 1 - k
                t = k / max(1.0, w)
                i = int(np.clip(4.5 - t * 4.0 + (n[y, x] - 0.5) * 1.4, 0, 6))
                c.px(x, y, rp[i])
        # lit edge on the land side
        for y in range(T):
            c.px(0 if is_w else T - 1, y, rp[6 if is_w else 1])
    if mask & S and not (mask & N):
        # land below: only its top lip shows, as a thin shadow along our bottom edge
        for x in range(T):
            c.px(x, T - 1, (0.05, 0.05, 0.10, 0.5))
            c.px(x, T - 2, (0.05, 0.05, 0.10, 0.25))
    return c


# ======================================================================== ship decks
def flagstone(variant):
    """Dressed quay paving: courses of slabs with mortar joints, a bevelled lit edge on each
    slab, per-slab tone, pits, hairline cracks and moss creeping along the joints."""
    rng = rng_for(f"flagstone{variant}")
    pals = [ramp("#7f766c", 7, 0.36), ramp("#79766f", 7, 0.36), ramp("#757671", 7, 0.36)]
    rows = [0, 10, 21, 32]
    slab = np.zeros((T, T), int)          # slab id
    sx0 = np.zeros((T, T), int)
    sx1 = np.zeros((T, T), int)
    slab_pal, slab_off, slab_crack = [], [], []
    sid = 0
    for r in range(3):
        ya, yb = rows[r], rows[r + 1]
        # joints in this course; wrapped, so the tile repeats seamlessly
        pos = rng.randint(0, 31)
        cuts = [pos]
        while True:
            pos += rng.randint(11, 19)
            if pos - cuts[0] >= 32 - 8:
                break
            cuts.append(pos)
        cuts.append(cuts[0] + 32)
        for k in range(len(cuts) - 1):
            a, b = cuts[k], cuts[k + 1]
            slab_pal.append(rng.choices([0, 1, 2], [3, 4, 2])[0])
            slab_off.append(rng.uniform(-0.06, 0.06))
            slab_crack.append(rng.random() < 0.28)
            for x in range(a, b):
                for y in range(ya, yb):
                    xx = x % T
                    slab[y, xx] = sid
                    sx0[y, xx], sx1[y, xx] = a, b
            sid += 1
    grain = fbm(T, T, 900 + variant * 11, 3, 8)
    fine = value_noise(T, T, 2, 50 + variant)
    field = np.zeros((T, T))
    mortar = np.zeros((T, T), bool)
    for y in range(T):
        ya = 0 if y < 10 else (10 if y < 21 else 21)
        yb = 10 if y < 10 else (21 if y < 21 else 32)
        for x in range(T):
            i = slab[y, x]
            a, b = sx0[y, x], sx1[y, x]
            xr = x if x >= a else x + T          # position along the (possibly wrapped) slab
            dx0, dx1 = xr - a, b - 1 - xr
            dy0, dy1 = y - ya, yb - 1 - y
            v = 0.52 + slab_off[i] + (grain[y, x] - 0.5) * 0.42 + (fine[y, x] - 0.5) * 0.14
            if dx0 == 0 or dy0 == 0:
                mortar[y, x] = True
            elif dy0 == 1:
                v += 0.26
            elif dx0 == 1:
                v += 0.14
            elif dy1 == 0:
                v -= 0.14
            elif dx1 == 0:
                v -= 0.08
            field[y, x] = v
    # hairline cracks running in from inside a slab
    for i in range(sid):
        if not slab_crack[i]:
            continue
        ys, xs = np.nonzero(slab == i)
        if len(ys) == 0:
            continue
        j = rng.randrange(len(ys))
        x, y = int(xs[j]), int(ys[j])
        dx, dy = rng.choice([(1, 1), (-1, 1), (1, 0), (0, 1)])
        for _ in range(rng.randint(4, 9)):
            if slab[y % T, x % T] == i and not mortar[y % T, x % T]:
                field[y % T, x % T] -= 0.34
            x += dx
            y += dy if rng.random() < 0.7 else 0
    c = Canvas()
    for pi in range(3):
        img = quantize_ramp(np.clip(field, 0, 1), pals[pi], dither=True)
        for y in range(T):
            for x in range(T):
                if slab_pal[slab[y, x]] == pi:
                    c.a[y, x] = img[y, x]
    for y in range(T):
        for x in range(T):
            if mortar[y, x]:
                pl = pals[slab_pal[slab[y, x]]]
                c.a[y, x] = pl[1] if fine[y, x] > 0.35 else pl[2]
    # pits
    for _ in range(rng.randint(6, 12)):
        x, y = rng.randint(1, 30), rng.randint(1, 30)
        if not mortar[y, x]:
            pl = pals[slab_pal[slab[y, x]]]
            c.px(x, y, pl[1])
            if not mortar[y - 1, x]:
                c.px(x, y - 1, pl[5])
    # moss and weeds in the joints
    moss = ramp("#4a6a34", 5, 0.5)
    for _ in range(rng.randint(3, 9)):
        y, x = rng.randint(1, 30), rng.randint(1, 30)
        if mortar[y, x]:
            c.px(x, y, moss[rng.randint(2, 4)])
            if rng.random() < 0.6:
                c.px(x, y - 1, moss[3])
    return c


def deck_tile(variant, metal=False, open_deck=False):
    """Planking, caulked and worn. The weather deck is paler: it has been rained on."""
    rng = rng_for(f"deck{variant}{metal}{open_deck}")
    c = Canvas()
    base = "#5a6472" if metal else ("#8a6f4a" if open_deck else "#6e5637")
    pal = ramp(base, 7, 0.36)
    field = np.full((T, T), 0.50)
    field += (value_noise(T * 2, T, 2, rng.randint(0, 9999))[:, :T] - 0.5) * 0.16
    if metal:
        for oy in (0, 16):
            for ox in (0, 16):
                field[oy:oy + 1, ox:ox + 16] += 0.24
                field[oy + 15:oy + 16, ox:ox + 16] -= 0.28
                field[oy:oy + 16, ox:ox + 1] += 0.14
                field[oy:oy + 16, ox + 15:ox + 16] -= 0.22
        img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
        c.a[:] = img
        # rivets at every plate corner, and a scuff or two
        hi, lo = pal[6], shade(pal[1], -0.2)
        for oy in (0, 16):
            for ox in (0, 16):
                for (rx, ry) in ((ox + 3, oy + 3), (ox + 12, oy + 3), (ox + 3, oy + 12), (ox + 12, oy + 12)):
                    c.px(rx, ry, hi)
                    c.px(rx + 1, ry + 1, lo)
        for _ in range(3):
            x, y = rng.randint(2, 28), rng.randint(2, 28)
            for k in range(rng.randint(3, 7)):
                c.px(x + k, y + k // 2, pal[5])
        return c
    # planks running fore-and-aft: five rows each, every plank its own tone and grain
    tone = [rng.uniform(-0.10, 0.10) for _ in range(8)]
    grain = value_noise(T, T, 4, rng.randint(0, 9999))
    for y in range(T):
        p = min(y // 5, 6)
        r = y % 5
        v = field[y, :] + tone[p]
        v = v + (grain[(y // 2) * 2 % T, :] - 0.5) * 0.2
        if r == 0:
            v = v - 0.36                      # caulked seam
        elif r == 1:
            v = v + 0.18                      # lit lip of the plank
        elif r == 4:
            v = v - 0.08
        field[y, :] = v
    # plank butts, staggered, with a shadowed joint and a lit lip
    butts = []
    for y in range(0, 30, 5):
        bx = (rng.randint(0, 6) * 5 + variant * 7 + y * 3) % T
        butts.append((y, bx))
        for k in range(5):
            if y + k < T:
                field[y + k, bx] -= 0.30
                field[y + k, (bx + 1) % T] += 0.10
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    dark = shade(pal[1], -0.25)
    # nails: a pair at each butt end
    for (y, bx) in butts:
        for dx in (-3, 3):
            c.px((bx + dx) % T, y + 2, dark)
            c.px((bx + dx) % T, y + 1, pal[5])
    # a knot or two
    for _ in range(rng.randint(0, 2)):
        x, y = rng.randint(4, 27), rng.randint(2, 27)
        y = y - (y % 5) + 2
        c.px(x, y, dark)
        c.px(x + 1, y, pal[1])
        c.px(x - 1, y, pal[2])
        c.px(x, y - 1, pal[3])
    # salt bleaching on the weather deck
    if open_deck:
        for _ in range(rng.randint(5, 10)):
            x, y = rng.randint(0, 28), rng.randint(0, 31)
            for k in range(rng.randint(3, 7)):
                c.px(x + k, y, pal[5])
    return c


def hull_wood(mask):
    """Ship's side: tarred planking over frames, lap-strake seams lit from above, butt
    joints and iron rivets on the frames."""
    c = _wall_generic(mask, "#6b5336", "#4e3c26", "hullwood")
    top_end = FACE_Y - 1 if not (mask & S) else T - 1
    seam = hexc("#3f301f")
    lit = hexc("#8a6c46")
    rng = rng_for(f"hullwood{mask}")
    for y in range(0, top_end, 5):
        for x in range(T):
            c.px(x, y, seam)
            if y + 1 <= top_end:
                c.px(x, y + 1, lit if (x * 7 + y) % 5 else mix(lit, seam, 0.5))
    for y in range(0, top_end - 4, 5):
        bx = rng.randint(3, 28)
        for k in range(1, 5):
            if y + k <= top_end:
                c.px(bx, y + k, seam)
    rv = hexc("#9aa0a8")
    for x in (4, 27):
        for y in range(3, top_end - 1, 10):
            c.px(x, y, rv)
            c.px(x + 1, y + 1, hexc("#2c2a2a"))
    return c


def bulkhead(mask):
    """Interior partition: painted board, full height, and it does block sight."""
    c = _wall_generic(mask, "#7a6a54", "#5c4e3c", "bulkhead")
    top_end = FACE_Y - 1 if not (mask & S) else T - 1
    for y in range(0, top_end, 8):
        for x in range(T):
            c.px(x, y, hexc("#6a5a46"))
    return c


def keel_wood(mask):
    """Doubled timber at bow and stern, banded with iron."""
    c = _wall_generic(mask, "#4f3f2a", "#3a2e1e", "keel")
    top_end = FACE_Y - 1 if not (mask & S) else T - 1
    band = hexc("#767c86")
    for x in (7, 8, 23, 24):
        for y in range(0, top_end + 1):
            c.px(x, y, band if x in (8, 24) else shade(band, -0.35))
    return c


# ======================================================================== registration
def build_into(add):
    """Append every Skyfarer terrain sprite. `add(name, canvas)` comes from tiles.build."""
    for v in range(8):
        add(f"sky_{v}", sky_tile(v))
    for v in range(4):
        add(f"cloud_{v}", cloud_tile(v))
    # --- biome ground
    for v in range(8):
        add(f"grass_{v}", ground("grass", "#4e7a3a", v, grain=5, tufts=10, tuft_col="#3a5f28",
                                 speckle=("#7aa855", 14)))
    for v in range(4):
        add(f"grasstall_{v}", ground("grasstall", "#47702f", v, grain=4, tufts=26, tuft_col="#33551f",
                                     speckle=("#86b45e", 10)))
        add(f"dirt_{v}", ground("dirt", "#6b5439", v, grain=6, speckle=("#4e3c28", 18), pebbles=7, streak=2))
        add(f"moss_{v}", ground("moss", "#3f6448", v, grain=4, tufts=8, tuft_col="#2c4a34",
                                speckle=("#6d9a72", 20)))
        add(f"ash_{v}", ground("ash", "#5a5450", v, grain=7, speckle=("#3a3632", 16), streak=2))
        add(f"mud_{v}", ground("mud", "#4e4030", v, grain=5, speckle=("#33291e", 14), streak=1))
        add(f"salt_{v}", ground("salt", "#c9c6bb", v, spread=0.22, grain=8, cracks=3))
        add(f"bonedust_{v}", ground("bonedust", "#b0a893", v, spread=0.26, grain=6,
                                    speckle=("#e0d8c4", 12)))
        add(f"basalt_{v}", ground("basalt", "#3c3a3e", v, grain=6, cracks=2, speckle=("#57555c", 12)))
        add(f"water_{v}", water_tile(v))
        add(f"lava_{v}", water_tile(v, lava=True))
    for v in range(6):
        add(f"sand_{v}", ground("sand", "#c2a874", v, spread=0.26, grain=7, streak=3,
                                speckle=("#a68c5a", 12), pebbles=2))
        add(f"stone_{v}", flagstone(v))
    # --- island rock, ore veins and brush
    for m in range(16):
        add(f"rock_aether_{m}", isle_rock(m, "aether"))
        add(f"rock_sulfur_{m}", isle_rock(m, "sulfur"))
        add(f"rock_crystal_{m}", isle_rock(m, "crystal"))
        add(f"thicket_{m}", thicket_tile(m))
        add(f"isle_edge_{m}", isle_edge(m))
    # --- ship
    for v in range(4):
        add(f"deck_{v}", deck_tile(v))
        add(f"deckplate_{v}", deck_tile(v, metal=True))
        add(f"deckopen_{v}", deck_tile(v, open_deck=True))
    for m in range(16):
        add(f"hullwood_{m}", hull_wood(m))
        add(f"keel_{m}", keel_wood(m))
        add(f"bulkhead_{m}", bulkhead(m))
