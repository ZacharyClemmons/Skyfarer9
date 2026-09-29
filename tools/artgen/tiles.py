"""Terrain: exterior snow/ice/rock, station floors, autotiled 3/4 walls, windows."""
import numpy as np

from common import (T, Canvas, fbm, hexc, mix, quantize_ramp, ramp, rng_for,
                    shade, value_noise)

N, E, S, W = 1, 2, 4, 8
FACE_Y = 19  # wall front face starts at this row when the tile below is open


# ======================================================================== floors
def panel_floor(name, base, variant, grout="#000000", style="panel", accent=None):
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    pal = ramp(base, 7, 0.32)
    field = np.full((T, T), 0.5)
    field += (value_noise(T, T, 4, rng.randint(0, 9999)) - 0.5) * 0.10
    field += (value_noise(T, T, 1, rng.randint(0, 9999)) - 0.5) * 0.05
    if style == "panel":
        # single 32px panel, bevelled
        field[0:1, :] += 0.28
        field[:, 0:1] += 0.18
        field[1:2, 1:] += 0.10
        field[T - 1:, :] -= 0.34
        field[:, T - 1:] -= 0.26
    elif style == "quad":
        # four 16px sub tiles
        for oy in (0, 16):
            for ox in (0, 16):
                field[oy:oy + 1, ox:ox + 16] += 0.25
                field[oy:oy + 16, ox:ox + 1] += 0.15
                field[oy + 15:oy + 16, ox:ox + 16] -= 0.30
                field[oy:oy + 16, ox + 15:ox + 16] -= 0.24
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    # scuffs / dirt
    for _ in range(rng.randint(0, 3 if variant else 1)):
        x, y = rng.randint(3, 27), rng.randint(3, 27)
        ln = rng.randint(2, 6)
        col = shade(pal[3], -0.18)
        for i in range(ln):
            c.px(x + i, y + (i // 3), col)
    if variant == 3:
        # faint worn patch toward the middle of the panel
        m = fbm(T, T, rng.randint(0, 9999), 3, 16)
        ys, xs = np.nonzero(m > 0.66)
        for y, x in zip(ys, xs):
            if 3 < x < 28 and 3 < y < 28 and (x + y) % 2 == 0:
                c.px(x, y, pal[2])
    # rivets in corners
    if style == "panel":
        for (x, y) in ((3, 3), (28, 3), (3, 28), (28, 28)):
            c.px(x, y, shade(pal[3], -0.35))
            c.px(x - 1, y - 1, shade(pal[3], 0.25))
    if accent is not None:
        pass
    return c


def checker_floor(name, a, b, variant, size=8):
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    pa, pb = ramp(a, 5, 0.25), ramp(b, 5, 0.25)
    n = value_noise(T, T, 2, rng.randint(0, 999))
    for y in range(T):
        for x in range(T):
            pal = pa if ((x // size) + (y // size)) % 2 == 0 else pb
            lx, ly = x % size, y % size
            i = 2
            if ly == 0 or lx == 0:
                i = 3
            if ly == size - 1 or lx == size - 1:
                i = 1
            if n[y, x] > 0.85:
                i = max(0, i - 1)
            c.px(x, y, pal[i])
    return c


def wood_floor(name, variant):
    """Staggered honey-coloured planks with grain; 4 planks per tile, long joints."""
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    base = hexc("#a0703f")
    pal = ramp(base, 7, 0.33)
    grain = value_noise(T * 4, T, 1, rng.randint(0, 999))
    for row in range(4):
        tone = rng.uniform(-0.6, 0.6)
        joint = (row * 11 + variant * 5 + rng.randint(0, 6)) % 32
        for y in range(row * 8, row * 8 + 8):
            ly = y - row * 8
            for x in range(T):
                g = grain[(ly * 3 + row * 7) % T, (x * 2 + row * 13) % (T * 4)]
                v = 3.0 + tone + (g - 0.5) * 1.4 + np.sin(x * 0.45 + row * 2.0 + ly * 0.9) * 0.35
                if ly == 0:
                    v += 1.2
                if ly == 7:
                    v = 0.4
                if x == joint:
                    v = 0.8
                if x == (joint + 1) % T:
                    v += 0.8
                c.px(x, y, pal[int(np.clip(round(v), 0, 6))])
        # a knot now and then
        if rng.random() < 0.3:
            kx = rng.randint(3, 28)
            c.px(kx, row * 8 + 3, pal[1])
            c.px(kx + 1, row * 8 + 4, pal[1])
            c.px(kx, row * 8 + 4, pal[2])
    return c


def carpet_floor(name, base, variant):
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    pal = ramp(base, 5, 0.35)
    gold = hexc("#c9a24a")
    n = value_noise(T, T, 1, rng.randint(0, 99))
    for y in range(T):
        for x in range(T):
            i = 2 if n[y, x] < 0.7 else 1
            if (x + y) % 2 == 0 and n[y, x] > 0.9:
                i = 3
            c.px(x, y, pal[i])
    # diamond motif
    for t in range(8):
        for (x, y) in ((16 + t, 8 + t), (16 - t, 8 + t), (16 + t, 24 - t), (16 - t, 24 - t)):
            c.px(x, y, shade(pal[2], 0.25))
    c.px(16, 16, gold)
    return c


def plating(name, variant):
    rng = rng_for(f"{name}{variant}")
    c = Canvas()
    pal = ramp("#5a606c", 7, 0.35)
    field = np.full((T, T), 0.5) + (value_noise(T, T, 2, rng.randint(0, 999)) - 0.5) * 0.12
    for k in (0, 16):
        field[k, :] -= 0.28
        field[:, k] -= 0.28
        field[(k + 1) % T, :] += 0.16
        field[:, (k + 1) % T] += 0.12
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    for (x, y) in ((4, 4), (12, 4), (4, 12), (12, 12)):
        for ox in (0, 16):
            for oy in (0, 16):
                c.px(x + ox, y + oy, pal[1])
                c.px(x + ox - 1, y + oy - 1, pal[5])
    if variant >= 2:
        # rust stain
        m = value_noise(T, T, 6, rng.randint(0, 999)) > 0.74
        rust = ramp("#7a4a32", 3, 0.2)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            c.px(x, y, rust[1] if (x + y) % 2 else rust[0])
    return c


def grate(name, variant):
    c = Canvas()
    dark = ramp("#1e2128", 3, 0.3)
    bar = ramp("#6f7684", 5, 0.35)
    for y in range(T):
        for x in range(T):
            c.px(x, y, dark[0] if (x // 2 + y // 2) % 2 else dark[1])
    for y in range(0, T, 4):
        c.hline(0, T - 1, y, bar[3])
        c.hline(0, T - 1, y + 1, bar[1])
    for x in (0, 31):
        c.vline(x, 0, T - 1, bar[2])
    return c


# ======================================================================== exterior
SNOW = ["#6d7fae", "#8b9dc8", "#a9b9dd", "#c5d2ec", "#dce5f5", "#edf2fb", "#fafcff"]


def snow_tile(variant, deep=False, packed=False):
    rng = rng_for(f"snow{variant}{deep}{packed}")
    c = Canvas()
    pal = [hexc(h) for h in SNOW]
    if packed:
        pal = [mix(p, hexc("#c9d3e8"), 0.18) for p in pal]
    field = np.full((T, T), 0.74 if not deep else 0.80)
    field += (fbm(T, T, rng.randint(0, 9999), 3, 16) - 0.5) * 0.16
    field += (value_noise(T, T, 1, rng.randint(0, 9999)) - 0.5) * 0.07
    # wind streaks: a few short curved drifts
    if not packed:
        for _ in range(rng.randint(2, 4)):
            x0, y0 = rng.uniform(0, 32), rng.uniform(0, 32)
            ln = rng.randint(6, 13)
            bend = rng.uniform(-0.12, 0.12)
            for i in range(ln):
                x = int(x0 + i) % T
                y = int(y0 + i * 0.35 + bend * i * i) % T
                field[y, x] -= 0.09
                field[(y - 1) % T, x] += 0.06
    else:
        # compacted tracks
        for y in range(T):
            for x in range(T):
                if (x in (9, 10, 21, 22)) and rng.random() < 0.6:
                    field[y, x] -= 0.06
    if deep:
        # soft mounds
        for _ in range(2):
            cx, cy = rng.randint(6, 26), rng.randint(6, 26)
            r = rng.randint(6, 9)
            for y in range(T):
                for x in range(T):
                    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r
                    if d < 1:
                        lit = ((cx - x) + (cy - y)) / r  # light from top-left
                        field[y, x] += (1 - d) * 0.06 + lit * 0.07 * (1 - d)
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    # little shadow dimples + sparkles
    for _ in range(rng.randint(1, 4)):
        x, y = rng.randint(2, 29), rng.randint(2, 29)
        c.px(x, y, pal[3])
        c.px(x + 1, y, pal[4])
        c.px(x, y - 1, pal[6])
    for _ in range(rng.randint(2, 6)):
        c.px(rng.randint(0, 31), rng.randint(0, 31), hexc("#ffffff"))
    return c


def ice_tile(variant):
    rng = rng_for(f"ice{variant}")
    c = Canvas()
    pal = [hexc(h) for h in ("#3f6f9c", "#5689b4", "#6fa3c9", "#8bbddb", "#a9d4ea", "#c8e8f5", "#eaf8ff")]
    field = np.full((T, T), 0.5)
    field += (fbm(T, T, rng.randint(0, 999), 3, 16) - 0.5) * 0.3
    # diagonal sheen streaks
    for y in range(T):
        for x in range(T):
            d = (x + y + variant * 9) % 32
            if d in (3, 4):
                field[y, x] += 0.22
            elif d == 5:
                field[y, x] += 0.10
            if (x - y + 40 + variant * 5) % 37 == 0:
                field[y, x] += 0.12
    img = quantize_ramp(np.clip(field, 0, 1), pal, dither=True)
    c.a[:] = img
    # cracks: random walk lines
    crack = hexc("#2f5c86")
    crack_hi = hexc("#d9f2ff")
    for _ in range(rng.randint(0, 2)):
        x, y = rng.randint(0, 31), rng.randint(0, 31)
        ang = rng.random() * 6.28
        fx, fy = float(x), float(y)
        for i in range(rng.randint(10, 26)):
            ang += rng.uniform(-0.5, 0.5)
            fx += np.cos(ang)
            fy += np.sin(ang)
            px_, py_ = int(fx) % T, int(fy) % T
            c.px(px_, py_, crack)
            c.px(px_, (py_ + 1) % T, crack_hi)
    # trapped bubbles
    for _ in range(rng.randint(2, 5)):
        x, y = rng.randint(2, 29), rng.randint(2, 29)
        c.px(x, y, pal[6])
        c.px(x + 1, y + 1, pal[2])
    return c


def gravel_tile(variant):
    rng = rng_for(f"gravel{variant}")
    c = Canvas()
    base = ramp("#4d5260", 5, 0.4)
    c.rect(0, 0, 31, 31, base[1])
    n = value_noise(T, T, 2, rng.randint(0, 999))
    for y in range(T):
        for x in range(T):
            if n[y, x] > 0.5:
                c.px(x, y, base[2])
    for _ in range(26):
        x, y = rng.randint(0, 30), rng.randint(0, 30)
        col = base[rng.randint(2, 4)]
        c.px(x, y, col)
        c.px(x + 1, y, shade(col, -0.2))
        c.px(x, y + 1, base[0])
    # snow dusting in the gaps
    sn = fbm(T, T, rng.randint(0, 999), 3, 8)
    snowp = [hexc(h) for h in SNOW]
    for y in range(T):
        for x in range(T):
            if sn[y, x] > 0.6:
                c.px(x, y, snowp[4] if sn[y, x] < 0.7 else snowp[5])
    return c


def snow_edge(mask):
    """Overlay drawn on non-snow tiles: snow creeping in from sides in mask."""
    rng = rng_for(f"sedge{mask}")
    c = Canvas()
    pal = [hexc(h) for h in SNOW]
    n = value_noise(T, T * 4, 3, 42)
    for y in range(T):
        for x in range(T):
            depth = 99
            if mask & N:
                depth = min(depth, y)
            if mask & S:
                depth = min(depth, 31 - y)
            if mask & W:
                depth = min(depth, x)
            if mask & E:
                depth = min(depth, 31 - x)
            if depth == 99:
                continue
            # wobbly edge
            edge = 4 + (n[y, x] - 0.5) * 6 + np.sin((x + y) * 0.45) * 1.5
            if depth < edge:
                t = depth / max(edge, 0.1)
                idx = 5 if t < 0.5 else 4
                if edge - depth < 1.2:
                    idx = 3  # shaded lip
                c.px(x, y, pal[idx])
    return c


# ======================================================================== walls
def _wall_generic(mask, top_base, face_base, kind):
    rng = rng_for(f"{kind}{mask}")
    c = Canvas()
    tp = ramp(top_base, 7, 0.45)
    fp = ramp(face_base, 7, 0.45)
    open_s = not (mask & S)
    top_end = FACE_Y - 1 if open_s else T - 1
    # ---- top surface
    brushed = value_noise(T * 4, T, 1, 91 + (1 if kind == "rwall" else 0))
    for y in range(0, top_end + 1):
        for x in range(T):
            i = 3
            v = brushed[y, (x * 4 + y * 7) % (T * 4) // 1] if False else brushed[y, x * 4 % (T * 4)]
            # long horizontal brushed streaks
            if brushed[y, (x // 6 + y * 5) % (T * 4)] > 0.8:
                i = 4
            elif brushed[y, (x // 6 + y * 5 + 40) % (T * 4)] < 0.15:
                i = 2
            c.px(x, y, tp[i])
    # panel seams on top (continuous across neighbours)
    for x in range(T):
        if kind == "rwall":
            if (x % 16) == 0:
                c.vline(x, 0, top_end, tp[2])
    # inset edges where neighbour is open
    if not (mask & N):
        c.hline(0, T - 1, 0, tp[0])
        c.hline(0, T - 1, 1, tp[6])
        c.hline(0, T - 1, 2, tp[5])
    if not (mask & W):
        c.vline(0, 0, top_end, tp[0])
        c.vline(1, 1 if not mask & N else 0, top_end, tp[5])
    if not (mask & E):
        c.vline(T - 1, 0, top_end, tp[0])
        c.vline(T - 2, 1 if not mask & N else 0, top_end, tp[2])
    # inner trim line (gives the thick-wall look)
    inset = 5
    trim = tp[2]
    if not (mask & N):
        c.hline(inset if not mask & W else 0, T - 1 - inset if not mask & E else T - 1, inset, trim)
    if not (mask & W):
        c.vline(inset, inset if not mask & N else 0, top_end if not open_s else top_end - 2, trim)
    if not (mask & E):
        c.vline(T - 1 - inset, inset if not mask & N else 0, top_end if not open_s else top_end - 2, tp[4])
    if kind == "rwall":
        for (x, y) in ((8, 8), (24, 8), (8, 24), (24, 24)):
            if y <= top_end - 2:
                c.px(x, y, tp[1])
                c.px(x - 1, y - 1, tp[5])
    # ---- front face
    if open_s:
        c.hline(0, T - 1, FACE_Y, tp[6])  # lit lip
        for y in range(FACE_Y + 1, T):
            t = (y - FACE_Y) / (T - FACE_Y)
            for x in range(T):
                i = 5 - int(t * 3.2)
                c.px(x, y, fp[max(1, i)])
        # face panel details
        if kind == "wall":
            for x in range(0, T, 16):
                c.vline(x, FACE_Y + 1, T - 3, fp[1])
                c.vline(x + 1, FACE_Y + 1, T - 3, fp[5])
            c.hline(0, T - 1, FACE_Y + 6, fp[2])
        elif kind == "hull":
            # crawler hull: painted armour with a black/yellow hazard band and rivets
            yb = FACE_Y + 4
            for x in range(T):
                for y in range(yb, yb + 3):
                    c.px(x, y, hexc("#e8c040") if ((x + y) // 3) % 2 == 0 else hexc("#1e1c22"))
            c.hline(0, T - 1, yb - 1, fp[1])
            c.hline(0, T - 1, yb + 3, fp[1])
            for x in range(3, T, 7):
                c.px(x, FACE_Y + 2, fp[6])
                c.px(x, FACE_Y + 9, fp[1])
        else:
            for x in range(2, T, 8):
                c.px(x, FACE_Y + 3, fp[1])
                c.px(x, FACE_Y + 9, fp[1])
            # hazard-ish bracing
            for x in range(T):
                y = FACE_Y + 2 + ((x // 2) % 8)
                if y < T - 3 and (x % 16) < 15:
                    c.px(x, y, fp[2])
        c.hline(0, T - 1, T - 2, fp[0])  # skirting
        c.hline(0, T - 1, T - 1, hexc("#15141c"))
        if not (mask & W):
            c.vline(0, FACE_Y, T - 1, fp[0])
        if not (mask & E):
            c.vline(T - 1, FACE_Y, T - 1, fp[0])
    return c


def wall_tile(mask):
    return _wall_generic(mask, "#646c7c", "#7a8394", "wall")


def rwall_tile(mask):
    return _wall_generic(mask, "#535a69", "#667080", "rwall")


def hull_tile(mask):
    """Evacuation crawler hull: white titanium roof, safety-orange sides."""
    c = _wall_generic(mask, "#c3cad4", "#c8622e", "hull")
    # roof seams + rivet rows so it reads as a vehicle, not a building
    top_end = FACE_Y - 1 if not (mask & S) else T - 1
    seam = hexc("#8e97a6")
    for y in range(0, top_end - 1, 8):
        for x in range(2 if not mask & W else 0, T - (2 if not mask & E else 0)):
            if (x + y) % 4 == 0:
                c.px(x, y + 4, seam)
    return c


def _facets(rng, npts):
    pts = [(rng.uniform(0, 32), rng.uniform(0, 32), rng.uniform(-1, 1)) for _ in range(npts)]
    out = []
    for y in range(T):
        row = []
        for x in range(T):
            best, second, bi = 1e9, 1e9, 0
            for k, (px_, py_, l) in enumerate(pts):
                dx = min(abs(x - px_), 32 - abs(x - px_))
                dy = min(abs(y - py_), 32 - abs(y - py_))
                d = dx * dx + dy * dy
                if d < best:
                    second, best, bi = best, d, k
                elif d < second:
                    second = d
            row.append((bi, (second ** 0.5 - best ** 0.5) < 1.1, pts[bi][2]))
        out.append(row)
    return out


_FACETS = None


def rock_tile(mask, ore=None, variant=0):
    global _FACETS
    if _FACETS is None:
        import random as _r
        _FACETS = _facets(_r.Random(1234), 10)
    """Snow-capped asteroid rock with icicles on exposed faces."""
    rng = rng_for(f"rock{mask}{ore}{variant}")
    c = Canvas()
    rp = ramp("#667086", 7, 0.5)
    snow = [hexc(h) for h in SNOW]
    open_s = not (mask & S)
    top_end = FACE_Y - 1 if open_s else T - 1
    n = fbm(T, T, 11 + mask, 3, 8)
    facet = _FACETS
    sn = fbm(T, T, 77 + mask * 3 + variant * 17, 3, 16)
    for y in range(0, top_end + 1):
        for x in range(T):
            fid, border, lit = facet[y][x]
            i = int(np.clip(3 + lit * 2.2 + (n[y, x] - 0.5) * 1.2, 0, 6))
            col = rp[i]
            if border:
                col = rp[max(0, i - 2)]
            # snow settles on the facets facing up (lit) and near the north rim
            s_ = sn[y, x] + lit * 0.12 + (0.14 if (not mask & N and y < 9) else 0)
            if s_ > 0.62:
                col = snow[5] if s_ > 0.7 else snow[4]
                if border:
                    col = snow[3]
            c.px(x, y, col)
    # edges: rounded lumpy rim
    edge_n = value_noise(T, T, 4, 5 + mask)
    for y in range(0, top_end + 1):
        for x in range(T):
            d = 99
            if not mask & N:
                d = min(d, y)
            if not mask & W:
                d = min(d, x)
            if not mask & E:
                d = min(d, T - 1 - x)
            lump = 2 + edge_n[y, x] * 2.5
            if d < lump:
                c.px(x, y, (0, 0, 0, 0))
            elif d < lump + 1:
                c.px(x, y, snow[6] if (not mask & N and y < 8) or (not mask & W and x < 8) else snow[2])
    if open_s:
        # rocky face with strata
        for y in range(FACE_Y, T):
            for x in range(T):
                d = 99
                if not mask & W:
                    d = min(d, x)
                if not mask & E:
                    d = min(d, T - 1 - x)
                lump = 2 + edge_n[min(y, T - 1), x] * 2.5
                if d < lump:
                    continue
                t = (y - FACE_Y) / (T - FACE_Y)
                strata = np.sin(y * 1.3 + np.sin(x * 0.4) * 1.5 + mask) * 0.5 + 0.5
                i = int(4.5 - t * 3 + strata * 1.2 + (n[y, x] - 0.5))
                c.px(x, y, rp[max(0, min(6, i))])
        # snow overhang lip
        for x in range(T):
            if c.get(x, FACE_Y)[3] > 0:
                c.px(x, FACE_Y, snow[6])
                c.px(x, FACE_Y + 1, snow[4] if (x + mask) % 3 else snow[5])
        # icicles
        icep = [hexc(h) for h in ("#8bbddb", "#c8e8f5", "#eaf8ff")]
        for x in range(2, T - 2, 3):
            if rng.random() < 0.55 and c.get(x, FACE_Y + 2)[3] > 0:
                ln = rng.randint(2, 6)
                for i in range(ln):
                    c.px(x, FACE_Y + 2 + i, icep[2] if i == 0 else (icep[1] if i < ln - 1 else icep[0]))
        # dark base
        for x in range(T):
            if c.get(x, T - 1)[3] > 0:
                c.px(x, T - 1, rp[0])
    if ore:
        oc = {"iron": ("#b26a3a", "#e0995b"), "plasma": ("#8a3cc4", "#e08bff"),
              "cryo": ("#2ec4d6", "#b8fbff"), "gold": ("#c49a2e", "#ffe27a")}[ore]
        for _ in range(9):
            x, y = rng.randint(4, 27), rng.randint(4, 29)
            if c.get(x, y)[3] > 0 and c.get(x + 1, y + 1)[3] > 0:
                c.px(x, y, hexc(oc[1]))
                c.px(x + 1, y, hexc(oc[0]))
                c.px(x, y + 1, hexc(oc[0]))
                c.px(x + 1, y + 1, shade(hexc(oc[0]), -0.4))
    return c


def window_tile(mask, reinforced=True):
    """Full-tile window pane on a low frame; frames join to neighbours."""
    c = Canvas()
    fr = ramp("#5c6474" if reinforced else "#707888", 5, 0.4)
    glass = [hexc(h) for h in ("#253a55", "#2f4d6e", "#3d6689", "#5d8db0", "#9fd0ec", "#e2f6ff")]
    # glass fill (semi transparent so floor lights show through)
    for y in range(T):
        for x in range(T):
            v = 1 if (x + y) % 11 else 2
            col = glass[v].copy()
            col[3] = 0.78
            c.px(x, y, col)
    # reflection streaks
    for i in range(T):
        for off, g in ((6, 4), (7, 3), (13, 3)):
            x = i
            y = off + 20 - i
            if 0 <= y < T:
                col = glass[g].copy()
                col[3] = 0.85
                c.px(x, y, col)
    # frame on non-connected sides
    fw = 3
    for side, bit in ((N, N), (E, E), (S, S), (W, W)):
        if mask & bit:
            continue
        for k in range(fw):
            col = fr[3] if k == 0 else fr[2 if k == 1 else 1]
            if side == N:
                c.hline(0, T - 1, k, col if k else fr[4])
            if side == S:
                c.hline(0, T - 1, T - 1 - k, fr[0] if k == 0 else fr[1])
            if side == W:
                c.vline(k, 0, T - 1, fr[4] if k == 0 else fr[2])
            if side == E:
                c.vline(T - 1 - k, 0, T - 1, fr[0] if k == 0 else fr[1])
    if reinforced:
        # grille rods
        for x in (10, 21):
            for y in range(T):
                if c.get(x, y)[3] < 0.95:
                    col = fr[1].copy()
                    c.px(x, y, col)
    # sparkle glint
    c.px(5, 5, glass[5])
    c.px(6, 4, glass[5])
    return c


def window_cracks(stage):
    """tg window damage overlay (icons/obj/structures.dmi "damage75/50/25"): cracks that
    spread from impact points as the pane loses integrity. stage 1..3 = 75%, 50%, 25%."""
    import math
    c = Canvas()
    rng = rng_for(f"wcrack{stage}")
    hi = hexc("#eaf8ff", 0.9)
    mid = hexc("#a8d4ec", 0.6)
    dark = hexc("#0e1a28", 0.45)
    hits = [(19, 12), (10, 21), (23, 24)][:stage]
    for n, (cx, cy) in enumerate(hits):
        rays = 5 + stage - n
        reach = 7 + stage * 3 - n * 2
        # the star of radial cracks
        tips = []
        for k in range(rays):
            a = (k / rays) * 6.283 + rng.uniform(-0.35, 0.35)
            x, y = float(cx), float(cy)
            ln = reach * rng.uniform(0.55, 1.1)
            steps = int(ln)
            for i in range(steps):
                a += rng.uniform(-0.28, 0.28)
                x += math.cos(a)
                y += math.sin(a)
                ix, iy = int(round(x)), int(round(y))
                if not (1 <= ix < T - 1 and 1 <= iy < T - 1):
                    break
                c.px(ix + 1, iy + 1, dark)
                c.px(ix, iy, hi if i < steps * 0.4 else mid)
                # small side branches further out
                if i > 3 and rng.random() < 0.06 * stage:
                    ba = a + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1)
                    bx, by = x, y
                    for _ in range(rng.randint(2, 4)):
                        bx += math.cos(ba)
                        by += math.sin(ba)
                        c.px(int(round(bx)), int(round(by)), mid)
            tips.append((x, y))
        # concentric ring fractures joining the rays (the spider web)
        if stage >= 2:
            for ring in (0.5, 0.85)[: stage - 1] if n == 0 else (0.55,):
                pts = [(cx + (tx - cx) * ring, cy + (ty - cy) * ring) for tx, ty in tips]
                for i in range(len(pts)):
                    x0, y0 = pts[i]
                    x1, y1 = pts[(i + 1) % len(pts)]
                    if rng.random() < 0.6:
                        c.line(int(x0), int(y0), int(x1), int(y1), mid)
        # the pulverised impact point
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                c.px(cx + dx, cy + dy, hexc("#f4fcff", 0.7 if dx or dy else 1.0))
    if stage == 3:
        # frosted, crazed glass over the whole pane
        for _ in range(18):
            x, y = rng.randint(2, T - 3), rng.randint(2, T - 3)
            c.px(x, y, hexc("#dff4ff", 0.3))
    return c


def floor_shadow(kind):
    """Ambient occlusion overlays drawn on floors next to walls."""
    c = Canvas()
    if kind == "n":
        for y in range(7):
            a = 0.42 * (1 - y / 7) ** 1.6
            c.hline(0, T - 1, y, (0.03, 0.03, 0.1, a))
    elif kind == "w":
        for x in range(4):
            a = 0.25 * (1 - x / 4) ** 1.5
            c.vline(x, 0, T - 1, (0.03, 0.03, 0.1, a))
    elif kind == "e":
        for x in range(4):
            a = 0.25 * (1 - x / 4) ** 1.5
            c.vline(T - 1 - x, 0, T - 1, (0.03, 0.03, 0.1, a))
    return c


# ======================================================================== build
def build(manifest):
    from common import sheet, save
    tiles = []
    names = []

    def add(name, cv):
        names.append(name)
        tiles.append(cv)

    floors = {
        "steel": ("#7a8292", "panel"), "white": ("#d6dde6", "panel"), "dark": ("#434957", "panel"),
        "blue": ("#4d6386", "panel"), "red": ("#7a4a50", "panel"), "yellow": ("#8a7a4a", "panel"),
        "purple": ("#6a5a86", "panel"), "green": ("#4e7a62", "panel"), "tealmed": ("#b7d6d9", "quad"),
    }
    for fname, (col, style) in floors.items():
        for v in range(4):
            add(f"floor_{fname}_{v}", panel_floor(fname, col, v, style=style))
    for v in range(4):
        add(f"floor_wood_{v}", wood_floor("wood", v))
        add(f"floor_freezer_{v}", checker_floor("freezer", "#c4dbe6", "#a7c3d3", v, 8))
        add(f"floor_cafe_{v}", checker_floor("cafe", "#dcd6c8", "#3c3f48", v, 8))
        add(f"floor_carpet_{v}", carpet_floor("carpet", "#7a2e3a", v))
        add(f"floor_bluecarpet_{v}", carpet_floor("bcarpet", "#2e3f7a", v))
        add(f"plating_{v}", plating("plating", v))
        add(f"grate_{v}", grate("grate", v))
    for v in range(8):
        add(f"snow_{v}", snow_tile(v))
    for v in range(4):
        add(f"deepsnow_{v}", snow_tile(v, deep=True))
        add(f"packed_{v}", snow_tile(v, packed=True))
        add(f"ice_{v}", ice_tile(v))
        add(f"gravel_{v}", gravel_tile(v))
    for m in range(16):
        add(f"snowedge_{m}", snow_edge(m))
    for m in range(16):
        add(f"wall_{m}", wall_tile(m))
    for m in range(16):
        add(f"rwall_{m}", rwall_tile(m))
    # Skyfarer: island stone rather than Artic9's snow-capped asteroid rock, so the same
    # sprite reads correctly under a meadow, a desert and a boneyard. Hoarfrost islands get
    # their winter from the snow ground tiles around it.
    from sky_tiles import isle_rock
    for v in range(3):
        for m in range(16):
            add(f"rock_{m}_{v}", isle_rock(m, None, v))
    for ore in ("iron", "plasma", "cryo", "gold"):
        for m in range(16):
            add(f"rock_{ore}_{m}", isle_rock(m, ore, 0))
    for m in range(16):
        add(f"hull_{m}", hull_tile(m))
    for v in range(4):
        add(f"floor_shuttle_{v}", panel_floor("shuttle", "#4c566a", v, style="quad"))
    # tg engine floor (the gas chambers): heavy bolted plates
    add("floor_engine_0", panel_floor("engine", "#3e434e", 0, style="quad"))
    for m in range(16):
        add(f"window_{m}", window_tile(m, False))
    for m in range(16):
        add(f"rwindow_{m}", window_tile(m, True))
    for st, pct in ((1, 75), (2, 50), (3, 25)):
        add(f"window_damage{pct}", window_cracks(st))
    for k in ("n", "w", "e"):
        add(f"ao_{k}", floor_shadow(k))
    # Skyfarer: open sky, island ground, ore veins, brush, cliffs and ship decks
    from sky_tiles import build_into as sky_build
    sky_build(add)

    cols = 16
    s = sheet(tiles, cols)
    save(s, "terrain.png")
    for i, n in enumerate(names):
        manifest["terrain"][n] = [i % cols, i // cols]
    return s
