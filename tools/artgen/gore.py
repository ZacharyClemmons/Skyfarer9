"""Blood and gore sprites after tg's icons/effects/blood.dmi states: pools (floor1-7),
splatters (gibbl1-5), drips (drip1-5), hit splatters, light and heavy drag trails, gibs
(gib1-6, gibtorso, gibhead, gibarm/gibleg, gibmid1-3), and severed limbs.

Blood is drawn wet and red; the game darkens it as it dries (tg get_dried_color). Pools
are metaball blobs with tendrils and satellite droplets, shaded deep in the middle with a
glossy lit rim and specular dots, so no two tiles look alike."""
import math

import numpy as np

from common import Canvas, ellipse_mask, hexc, rng_for, sel_outline

# wet blood: outline, deep, mid, light, gloss
BL = [hexc(h) for h in ("#2e0409", "#5e0a13", "#861220", "#ad1f2d", "#e0707a")]
# viscera / meat
MEAT = [hexc(h) for h in ("#3a0c10", "#7a1c24", "#a8323a", "#cc5a5a", "#e89090")]
FAT = [hexc(h) for h in ("#b8904a", "#e0c070", "#f4e0a0")]
BONE = [hexc(h) for h in ("#8a8070", "#d8d0b8", "#f6f2e4")]
SKIN = [hexc(h) for h in ("#5a3424", "#9a6448", "#c8906a", "#e4b490", "#f4d4b4")]


def _field(blobs, w=32, h=32, warp=0.0, seed=0):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    if warp:
        from common import value_noise
        nx = value_noise(w, h, 4, seed, periodic=False) - 0.5
        ny = value_noise(w, h, 4, seed + 7, periodic=False) - 0.5
        xx = xx + nx * warp
        yy = yy + ny * warp
    f = np.zeros((h, w))
    for (cx, cy, r) in blobs:
        d2 = (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 + 0.3
        f += (r * r) / d2
    return f


def _dist_in(mask):
    """Chebyshev-ish distance of each inside pixel to the edge (0 = edge pixel)."""
    d = np.zeros(mask.shape)
    cur = mask.copy()
    k = 0
    while cur.any():
        er = cur.copy()
        er[1:, :] &= cur[:-1, :]
        er[:-1, :] &= cur[1:, :]
        er[:, 1:] &= cur[:, :-1]
        er[:, :-1] &= cur[:, 1:]
        d[cur & ~er] = k
        cur = er
        k += 1
    return d


def _paint_wet(cv, mask, rng, gloss=True, pal=BL, light=(-1, -1)):
    """Deep in the middle, lighter toward a lit edge, dark rim, glossy dots."""
    if not mask.any():
        return
    d = _dist_in(mask)
    h, w = mask.shape
    lx, ly = light
    for y, x in zip(*np.nonzero(mask)):
        # lit side: neighbour toward the light is outside
        lit = 0
        for s in (1, 2):
            nx, ny = x + lx * s, y + ly * s
            if not (0 <= nx < w and 0 <= ny < h) or not mask[ny, nx]:
                lit += 1 if s == 1 else 0.5
        dark = 0
        for s in (1, 2):
            nx, ny = x - lx * s, y - ly * s
            if not (0 <= nx < w and 0 <= ny < h) or not mask[ny, nx]:
                dark += 1
        if d[y, x] == 0 and dark:
            c = pal[0]
        elif lit >= 1:
            c = pal[3]
        elif d[y, x] >= 3:
            c = pal[1]
        elif d[y, x] == 0:
            c = pal[1]
        else:
            c = pal[2]
        cv.px(x, y, c)
    if gloss:
        ys, xs = np.nonzero(d >= 2)
        if len(xs):
            for _ in range(max(1, len(xs) // 40)):
                i = rng.randint(0, len(xs) - 1)
                cv.px(xs[i], ys[i], pal[4])
                if rng.random() < 0.5 and xs[i] + 1 < w and mask[ys[i], xs[i] + 1]:
                    cv.px(xs[i] + 1, ys[i], pal[3])


def _droplets(cv, rng, cx, cy, n, rmin, rmax, spread=(-math.pi, math.pi)):
    for _ in range(n):
        a = rng.uniform(*spread)
        r = rng.uniform(rmin, rmax)
        x, y = int(round(cx + math.cos(a) * r)), int(round(cy + math.sin(a) * r))
        if not (1 <= x < 31 and 1 <= y < 31):
            continue
        big = rng.random() < 0.35
        cv.px(x, y, BL[2])
        if big:
            cv.px(x + 1, y, BL[1])
            cv.px(x, y + 1, BL[1])
            cv.px(x, y, BL[3])


def pool(v):
    """tg floor1-7: a pool of blood."""
    rng = rng_for(f"gore_pool{v}")
    cv = Canvas()
    cx, cy = 16 + rng.uniform(-2, 2), 16 + rng.uniform(-2, 2)
    blobs = [(cx, cy, rng.uniform(3.6, 4.8))]
    for _ in range(rng.randint(3, 6)):
        a = rng.uniform(0, math.tau)
        dd = rng.uniform(3, 7)
        blobs.append((cx + math.cos(a) * dd, cy + math.sin(a) * dd * 0.8, rng.uniform(1.4, 2.8)))
    field = _field(blobs, warp=5.0, seed=v * 13 + 1)
    m = field >= 1.25
    # tendrils: thin runs of blood out from the pool
    for _ in range(rng.randint(2, 5)):
        a = rng.uniform(0, math.tau)
        L = rng.uniform(9, 14)
        wd = rng.uniform(0.9, 1.4)
        bend = rng.uniform(-0.08, 0.08)
        for t in np.linspace(3, L, 18):
            aa = a + bend * t
            m |= ellipse_mask(32, 32, cx + math.cos(aa) * t, cy + math.sin(aa) * t, wd, wd)
            wd = max(0.55, wd * 0.95)
    _paint_wet(cv, m, rng)
    _droplets(cv, rng, cx, cy, rng.randint(5, 9), 9, 14)
    return cv


def splatter(v):
    """tg gibbl1-5: a spray of blood that hit the floor going one way."""
    rng = rng_for(f"gore_splat{v}")
    cv = Canvas()
    a0 = rng.uniform(0, math.tau)
    cx, cy = 16 - math.cos(a0) * 4, 16 - math.sin(a0) * 4
    blobs = [(cx, cy, rng.uniform(2.6, 3.4))]
    for i in range(rng.randint(5, 8)):
        a = a0 + rng.uniform(-0.55, 0.55)
        dd = rng.uniform(3, 11)
        blobs.append((cx + math.cos(a) * dd, cy + math.sin(a) * dd, rng.uniform(0.9, 2.0) * (1 - dd / 16)))
    m = _field(blobs) >= 1.0
    _paint_wet(cv, m, rng, light=(-1, -1))
    # streaked droplets flung further along the spray
    for _ in range(rng.randint(8, 14)):
        a = a0 + rng.uniform(-0.7, 0.7)
        dd = rng.uniform(8, 15)
        x, y = cx + math.cos(a) * dd, cy + math.sin(a) * dd
        L = rng.randint(1, 3)
        for t in range(L):
            px, py = int(round(x + math.cos(a) * t)), int(round(y + math.sin(a) * t))
            if 0 <= px < 32 and 0 <= py < 32:
                cv.px(px, py, BL[2] if t == 0 else BL[1])
    return cv


def drip(v):
    """tg drip1-5: a single drop that hit the floor, with its crown of specks."""
    rng = rng_for(f"gore_drip{v}")
    cv = Canvas()
    cx, cy = rng.randint(9, 23), rng.randint(9, 23)
    r = rng.uniform(1.2, 1.9)
    m = ellipse_mask(32, 32, cx, cy, r, r * rng.uniform(0.8, 1.0))
    _paint_wet(cv, m, rng, gloss=False)
    cv.px(cx - 1, cy - 1, BL[3])
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(2.5, 4.5)
        cv.px(int(round(cx + math.cos(a) * d)), int(round(cy + math.sin(a) * d)), BL[2])
    return cv


def hitsplatter(v):
    """tg hitsplatter1-3: blood in flight."""
    rng = rng_for(f"gore_hit{v}")
    cv = Canvas()
    for _ in range(9 + v * 3):
        x, y = 16 + rng.gauss(0, 3), 16 + rng.gauss(0, 3)
        cv.px(int(x), int(y), BL[rng.randint(1, 3)])
    m = ellipse_mask(32, 32, 16, 16, 2.2, 1.7)
    _paint_wet(cv, m, rng, gloss=False)
    return cv


def trail(heavy, horizontal, v):
    """tg ltrails_1/2 (light) and trails_1/2 (heavy): smears from a dragged body."""
    rng = rng_for(f"gore_trail{heavy}{horizontal}{v}")
    cv = Canvas()
    lanes = [(-2.5, 1.0), (0, 1.6), (2.5, 0.9)] if heavy else [(-2, 0.6), (2, 0.7)]
    m = np.zeros((32, 32), bool)
    for off, wd in lanes:
        off += rng.uniform(-1, 1)
        phase = rng.uniform(0, 6)
        for i in range(32):
            w = wd * (0.75 + 0.25 * math.sin(i * 0.3 + phase))
            if not heavy and rng.random() < 0.18:
                continue
            c = 16 + off + math.sin(i * 0.2 + phase) * 0.8
            for s in range(int(c - w), int(c + w) + 1):
                if 0 <= s < 32:
                    if horizontal:
                        m[s, i] = True
                    else:
                        m[i, s] = True
    _paint_wet(cv, m, rng, gloss=heavy)
    return cv


def _meat_chunk(cv, rng, cx, cy, rx, ry, fat=True, bone=True):
    m = ellipse_mask(32, 32, cx, cy, rx, ry)
    # ragged edge
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        m |= ellipse_mask(32, 32, cx + math.cos(a) * rx * 0.8, cy + math.sin(a) * ry * 0.8, rx * 0.45, ry * 0.45)
    # each chunk has its own dark outline so the pieces read apart
    ring = np.zeros_like(m)
    ring[1:, :] |= m[:-1, :]
    ring[:-1, :] |= m[1:, :]
    ring[:, 1:] |= m[:, :-1]
    ring[:, :-1] |= m[:, 1:]
    cv.mask_fill(ring & ~m, MEAT[0])
    _paint_wet(cv, m, rng, pal=[MEAT[1], MEAT[2], MEAT[3], MEAT[4], hexc("#f8d0d0")])
    # sinew streaks
    ys0, xs0 = np.nonzero(m)
    for _ in range(len(xs0) // 10):
        i = rng.randint(0, len(xs0) - 1)
        cv.px(xs0[i], ys0[i], MEAT[1])
    ys, xs = np.nonzero(m)
    if fat and len(xs):
        for _ in range(rng.randint(1, 3)):
            i = rng.randint(0, len(xs) - 1)
            cv.px(xs[i], ys[i], FAT[1])
            if xs[i] + 1 < 32:
                cv.px(xs[i] + 1, ys[i], FAT[0])
    if bone and len(xs) and rng.random() < 0.6:
        i = rng.randint(0, len(xs) - 1)
        cv.px(xs[i], ys[i], BONE[2])
        if ys[i] + 1 < 32:
            cv.px(xs[i], ys[i] + 1, BONE[1])
    return m


def _under_pool(cv, rng, cx, cy, size):
    blobs = [(cx + rng.uniform(-3, 3), cy + rng.uniform(-1, 3), rng.uniform(size * 0.45, size * 0.7)) for _ in range(4)]
    m = _field(blobs, warp=4.0, seed=int(cx * 7 + cy)) >= 1.3
    _paint_wet(cv, m, rng, gloss=False)


def gib(v):
    """tg gib1-6: scattered chunks of someone."""
    rng = rng_for(f"gore_gib{v}")
    cv = Canvas()
    cx, cy = 16 + rng.uniform(-3, 3), 17 + rng.uniform(-3, 3)
    _under_pool(cv, rng, cx, cy + 1, 4.0)
    for _ in range(rng.randint(2, 4)):
        _meat_chunk(cv, rng, cx + rng.uniform(-6, 6), cy + rng.uniform(-5, 4), rng.uniform(1.8, 3.2), rng.uniform(1.4, 2.6))
    # a loop of intestine on some
    if v % 3 == 0:
        a0 = rng.uniform(0, math.tau)
        for t in range(14):
            a = a0 + t * 0.55
            r = 3 + t * 0.35
            x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.7)
            cv.px(x, y, MEAT[3])
            cv.px(x, y + 1, MEAT[1])
    _droplets(cv, rng, cx, cy, rng.randint(4, 8), 8, 13)
    sel_outline(cv, color=BL[0])
    return cv


def gib_core(v):
    """tg gibmid1-3: the big middle heap."""
    rng = rng_for(f"gore_core{v}")
    cv = Canvas()
    _under_pool(cv, rng, 16, 19, 7.0)
    for _ in range(6):
        _meat_chunk(cv, rng, 16 + rng.uniform(-7, 7), 17 + rng.uniform(-6, 5), rng.uniform(1.8, 3.2), rng.uniform(1.4, 2.6))
    # a couple of rib shards
    for _ in range(2 + v):
        x, y = rng.randint(9, 22), rng.randint(10, 22)
        a = rng.uniform(0, math.pi)
        for t in range(4):
            cv.px(int(x + math.cos(a) * t), int(y + math.sin(a) * t * 0.6), BONE[2] if t % 2 else BONE[1])
    _droplets(cv, rng, 16, 17, 8, 10, 15)
    sel_outline(cv, color=BL[0])
    return cv


def gib_torso():
    rng = rng_for("gore_torso")
    cv = Canvas()
    _under_pool(cv, rng, 16, 21, 6.0)
    # a skin-covered torso torn open down the middle
    body = ellipse_mask(32, 32, 16, 16, 6.0, 8.0)
    _paint_wet(cv, body, rng, pal=SKIN, gloss=False)
    wound = ellipse_mask(32, 32, 16, 16, 3.2, 6.5)
    cv.mask_fill(wound, MEAT[1])
    _paint_wet(cv, ellipse_mask(32, 32, 16, 16, 2.4, 5.5), rng, pal=[MEAT[0], MEAT[1], MEAT[2], MEAT[3], MEAT[4]])
    # ribs curving out of the opening
    for i in range(4):
        y = 11 + i * 3
        for s in (-1, 1):
            for t in range(3):
                cv.px(16 + s * (3 + t), y + (1 if t == 2 else 0), BONE[2] if t < 2 else BONE[1])
    for y in range(9, 24, 2):
        cv.px(16, y, BONE[2])
    _droplets(cv, rng, 16, 16, 7, 9, 14)
    sel_outline(cv, color=BL[0])
    return cv


def gib_head():
    rng = rng_for("gore_head")
    cv = Canvas()
    _under_pool(cv, rng, 16, 20, 5.0)
    m = ellipse_mask(32, 32, 16, 15, 6, 6.5)
    _paint_wet(cv, m, rng, pal=MEAT)
    skull = ellipse_mask(32, 32, 15, 13, 4, 3.5)
    _paint_wet(cv, skull, rng, pal=[BONE[0], BONE[1], BONE[1], BONE[2], BONE[2]], gloss=False)
    cv.px(13, 16, BL[0])
    cv.px(17, 16, BL[0])
    for x in range(12, 20):
        cv.px(x, 19 + (x % 2), BONE[2] if x % 2 else MEAT[0])
    sel_outline(cv, color=BL[0])
    return cv


def gib_limb(kind):
    rng = rng_for(f"gore_limb{kind}")
    cv = Canvas()
    _under_pool(cv, rng, 16, 18, 3.5)
    if kind == "arm":
        pts = [(9, 20), (13, 17), (18, 15), (22, 12)]
        width = 2.0
    else:
        pts = [(8, 22), (13, 18), (19, 14), (24, 10)]
        width = 2.6
    m = np.zeros((32, 32), bool)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for t in np.linspace(0, 1, 8):
            m |= ellipse_mask(32, 32, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width, width)
    _paint_wet(cv, m, rng, pal=MEAT)
    cv.px(pts[-1][0], pts[-1][1], BONE[2])
    cv.px(pts[-1][0] + 1, pts[-1][1], BONE[1])
    sel_outline(cv, color=BL[0])
    return cv


def severed_limb(kind):
    """A severed arm, leg or head: skin with a wet, bony stump."""
    rng = rng_for(f"gore_sev{kind}")
    cv = Canvas()
    if kind == "head":
        m = ellipse_mask(32, 32, 16, 15, 6.2, 6.8)
        _paint_wet(cv, m, rng, pal=SKIN, gloss=False)
        # hair cap and closed eyes
        hair = m & (np.mgrid[0:32, 0:32][0] < 12)
        cv.mask_fill(hair, hexc("#3a2418"))
        for x in (13, 18):
            cv.px(x, 15, SKIN[0])
            cv.px(x + 1, 15, SKIN[0])
        cv.px(16, 19, SKIN[1])
        cv.px(17, 19, SKIN[1])
        # neck stump
        st = ellipse_mask(32, 32, 16, 22, 3.2, 1.6)
        _paint_wet(cv, st, rng, pal=MEAT, gloss=False)
        cv.px(16, 22, BONE[2])
        _droplets(cv, rng, 16, 24, 5, 3, 6, (0.3, 2.8))
    else:
        leg = kind == "leg"
        pts = [(7, 24), (13, 19), (19, 14), (25, 9)] if leg else [(8, 22), (14, 18), (20, 14), (24, 12)]
        width = 2.6 if leg else 2.0
        m = np.zeros((32, 32), bool)
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            for t in np.linspace(0, 1, 8):
                m |= ellipse_mask(32, 32, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width, width)
        # hand / foot at the far end
        ex, ey = pts[0]
        if leg:
            m |= ellipse_mask(32, 32, ex - 1, ey + 1, 3.4, 1.8)
        else:
            m |= ellipse_mask(32, 32, ex - 1, ey + 1, 2.2, 2.2)
        _paint_wet(cv, m, rng, pal=SKIN, gloss=False)
        if leg:
            ms = ellipse_mask(32, 32, ex - 1, ey + 1, 3.4, 1.8)
            cv.mask_fill(ms, hexc("#1e1c24"))  # shoe
        # the stump end
        sx, sy = pts[-1]
        st = ellipse_mask(32, 32, sx, sy, width + 0.4, width + 0.4)
        _paint_wet(cv, st, rng, pal=MEAT, gloss=True)
        cv.px(sx, sy, BONE[2])
        cv.px(sx + 1, sy, BONE[1])
        _droplets(cv, rng, sx, sy, 5, 3, 6)
    sel_outline(cv)
    return cv


def add_objects(pk):
    for v in range(7):
        pk.add(f"blood_floor_{v}", pool(v))
    for v in range(5):
        pk.add(f"blood_splatter_{v}", splatter(v))
    for v in range(5):
        pk.add(f"blood_drop_{v}", drip(v))
    for v in range(3):
        pk.add(f"blood_hitsplatter_{v}", hitsplatter(v))
    for heavy in (0, 1):
        for v in range(2):
            pk.add(f"blood_{'trails' if heavy else 'ltrails'}_{v}_h", trail(heavy, True, v))
            pk.add(f"blood_{'trails' if heavy else 'ltrails'}_{v}_v", trail(heavy, False, v))
    for v in range(6):
        pk.add(f"gore_gib_{v}", gib(v))
    for v in range(3):
        pk.add(f"gore_gibmid_{v}", gib_core(v))
    pk.add("gore_gibtorso", gib_torso())
    pk.add("gore_gibhead", gib_head())
    pk.add("gore_gibarm", gib_limb("arm"))
    pk.add("gore_gibleg", gib_limb("leg"))


def add_items(pk):
    for k in ("arm", "leg", "head"):
        pk.add(f"limb_{k}", severed_limb(k))


def preview(path):
    """Contact sheet of everything on a floor tile colour, 4x scale."""
    from PIL import Image
    tiles = [pool(v) for v in range(7)] + [splatter(v) for v in range(5)] + [drip(v) for v in range(5)] + \
        [hitsplatter(v) for v in range(3)] + [trail(1, True, 0), trail(0, True, 0), trail(1, False, 1)] + \
        [gib(v) for v in range(6)] + [gib_core(v) for v in range(3)] + [gib_torso(), gib_head(), gib_limb("arm"), gib_limb("leg")] + \
        [severed_limb(k) for k in ("arm", "leg", "head")]
    cols = 8
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 34, rows * 34), (92, 96, 104, 255))
    for i, t in enumerate(tiles):
        im = t.image()
        sheet.alpha_composite(im, ((i % cols) * 34 + 1, (i // cols) * 34 + 1))
    sheet = sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST)
    sheet.save(path)


if __name__ == "__main__":
    import sys
    preview(sys.argv[1] if len(sys.argv) > 1 else "gore_preview.png")
