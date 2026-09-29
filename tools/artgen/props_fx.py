"""Final 'finish' pass for prop, machine and item sprites.

Runs on every packed sprite just before the sheet is written (objects.build and
items.build call `finish_objects` / `finish_items`). It does not redraw anything: it
adds what hand-drawn pixel art has and a base drawing lacks -- a firm outline,
top-left light with a lit rim and shaded underside, hue-shifted (warm light / cool
shadow) tone, specular glints on the brightest material, a little grime and edge
wear, and a contact shadow under things that stand on the floor. Sprite sizes,
anchors and transparency footprints are unchanged except for the outline ring
(added only into fully transparent pixels of the same canvas) and the shadow row.

Autotiling / tiling / decal sprites are skipped by name and by coverage.
"""
import zlib

import numpy as np

SKIP_PREFIX = (
    "pipe_", "cable_", "table_", "fence_", "edge_", "hazard", "blood", "glass_debris",
    "scorch", "puddle", "liquid", "footprints", "snowprints", "gore", "grime", "rug",
    "line_", "tread", "mouse", "ash", "drift", "arrow", "star", "lightning", "storm",
    "refraction", "void", "tide", "spore", "ember", "lava", "poster", "space", "sign_",
    "girder", "grille", "meter_", "curtain", "deck", "crust", "frost", "cliff",
)
# hung on a wall or flat on the floor: no ground shadow
NO_SHADOW = ("light_", "status", "intercom", "apc", "air_alarm", "fire_alarm", "extinguisher",
             "vent", "mirror", "emergency", "sign", "poster", "shower", "holofan", "display",
             "curtain", "lift", "port_", "rug", "bed_", "cap_")

DARK = np.array([0.075, 0.07, 0.115])


def _lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def _shift(m, dx, dy):
    """m shifted so out[y,x] = m[y+dy, x+dx] (False outside)."""
    h, w = m.shape
    out = np.zeros_like(m)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    out[ys0:ys1, xs0:xs1] = m[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
    return out


def _grade(rgb, mask, amount=1.0):
    """contrast + saturation lift around the sprite's own mean."""
    l = _lum(rgb)
    mean = l[mask].mean() if mask.any() else 0.5
    rgb = rgb.copy()
    lo = _lum(rgb)[..., None]
    rgb = lo + (rgb - lo) * (1.0 + 0.26 * amount)                 # saturation
    rgb = mean + (rgb - mean) * (1.0 + 0.27 * amount)             # contrast
    return np.clip(rgb, 0, 1)


def enhance(arr, name, kind="obj"):
    """arr: HxWx4 float. Returns a new array."""
    h, w = arr.shape[:2]
    a = arr[..., 3]
    mask = a > 0.5
    n = int(mask.sum())
    if n < 12:
        return arr
    if n > 0.80 * h * w:
        return arr                                   # tile-filling: leave for the tile art
    if a[mask].mean() < 0.9:
        return arr                                   # translucent decal / effect
    rng = np.random.default_rng(zlib.crc32(name.encode()))
    out = arr.copy()
    rgb = out[..., :3]

    ys, xs = np.nonzero(mask)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    bw, bh = x1 - x0 + 1, y1 - y0 + 1

    up = _shift(mask, 0, -1)     # neighbour above
    dn = _shift(mask, 0, 1)
    lf = _shift(mask, -1, 0)
    rt = _shift(mask, 1, 0)
    edge = mask & ~(up & dn & lf & rt)
    thin = mask & ((~up & ~dn) | (~lf & ~rt))
    lum0 = _lum(rgb)

    # -- 1. grade
    graded = _grade(rgb, mask, 1.0 if kind == "obj" else 0.8)
    rgb = np.where(mask[..., None], graded, rgb)

    # -- 2. light gradient across the sprite (top-left lit, bottom-right in shade)
    yy, xx = np.mgrid[0:h, 0:w]
    t = ((xx - x0) / max(1, bw - 1) * 0.45 + (yy - y0) / max(1, bh - 1) * 0.55)  # 0 tl .. 1 br
    t = np.clip(t, 0, 1)
    lit = np.clip(0.5 - t, 0, 0.5) * 2      # 1 at top-left
    shd = np.clip(t - 0.5, 0, 0.5) * 2      # 1 at bottom-right
    warm = np.array([1.0, 0.93, 0.62])
    cool = np.array([0.10, 0.13, 0.32])
    rgb = rgb + (lit * 0.15)[..., None] * warm * mask[..., None] * 0.9
    rgb = rgb * (1 - (shd * 0.26)[..., None] * mask[..., None]) + (shd * 0.08)[..., None] * cool * mask[..., None]
    rgb = np.clip(rgb, 0, 1)

    # -- 3. rim light on top/left inner edge, shade on bottom/right inner edge
    inner = mask & ~edge
    ring2_tl = mask & ((~_shift(mask, 0, -2) & up) | (~_shift(mask, -2, 0) & lf)) & inner
    ring2_br = mask & ((~_shift(mask, 0, 2) & dn) | (~_shift(mask, 2, 0) & rt)) & inner
    L = _lum(rgb)
    rgb = np.where(ring2_tl[..., None], np.clip(rgb + 0.20 * warm * (0.6 + 0.4 * (1 - L))[..., None] * 0.9, 0, 1), rgb)
    rgb = np.where(ring2_br[..., None], np.clip(rgb * 0.72 + 0.05 * cool, 0, 1), rgb)
    # outer edge pixels facing the light keep a brighter rim, facing away go dark
    face_tl = edge & (~up | ~lf) & ~thin
    face_br = edge & (~dn | ~rt) & ~thin
    # -- 4. outline: darken the outer ring (own hue shifted, not pure black) unless already dark
    need = edge & ~thin & (_lum(rgb) > 0.20)
    ol = np.clip(rgb * np.array([0.30, 0.30, 0.42]) + DARK * 0.55, 0, 1)
    k = np.where(face_br, 0.88, 0.68)[..., None]
    rgb = np.where(need[..., None], rgb * (1 - k) + ol * k, rgb)
    # top-left silhouette pixels that are not outlined get a light nick so the rim reads
    # (only on large objects, where the lit edge is a real edge)
    if bw >= 10 and bh >= 10:
        nick = face_tl & ~need & (_lum(rgb) > 0.20)
        rgb = np.where(nick[..., None], np.clip(rgb + 0.06, 0, 1), rgb)

    # -- 5. specular glints: brightest material in the upper-left half
    if kind == "obj" and bw >= 8 and bh >= 8:
        L = _lum(rgb)
        thr = np.percentile(L[inner], 93) if inner.any() else 1
        spec = inner & (L >= thr) & (t < 0.6) & (L > 0.55)
        rgb = np.where(spec[..., None], np.clip(rgb + 0.16, 0, 1) * np.array([1.0, 0.98, 0.9]) + 0.0, rgb)

    # -- 6. grime and wear (deterministic per sprite), only on larger solid props
    if kind == "obj" and bw >= 12 and bh >= 12 and not name.endswith("_glow"):
        low = inner & (yy > y0 + bh * 0.55)
        spots = low & (rng.random((h, w)) < 0.030)
        rgb = np.where(spots[..., None], rgb * 0.80 + 0.02 * cool, rgb)
        # drips / streaks of grime under upper edge details
        streak = inner & _shift(spots, 0, -1) & (rng.random((h, w)) < 0.5)
        rgb = np.where(streak[..., None], rgb * 0.90, rgb)
        chips = edge & face_tl & ~thin & (rng.random((h, w)) < 0.10)
        rgb = np.where(chips[..., None], np.clip(rgb + 0.18, 0, 1), rgb)

    out[..., :3] = np.where(mask[..., None], rgb, out[..., :3])

    # -- 7. outer outline ring into transparent pixels when the art has no outline of its own
    #    (item icons especially)
    if kind == "item":
        ring = ~mask & (up | dn | lf | rt)
        # only where the neighbour is not already dark (an existing outline)
        nb_l = np.zeros((h, w))
        cnt = np.zeros((h, w))
        col = np.zeros((h, w, 3))
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sm = _shift(mask, dx, dy)
            sc = np.zeros((h, w, 3))
            ys2, xs2 = np.nonzero(sm)
            sc[ys2, xs2] = out[ys2 + dy, xs2 + dx, :3]
            col += sc * sm[..., None]
            cnt += sm
        col = col / np.maximum(cnt, 1)[..., None]
        lum_n = _lum(col)
        add = ring & (lum_n > 0.22) & (a < 0.05)
        oc = np.clip(col * np.array([0.28, 0.28, 0.40]) + DARK * 0.5, 0, 1)
        out[..., :3] = np.where(add[..., None], oc, out[..., :3])
        out[..., 3] = np.where(add, 1.0, out[..., 3])

    # -- 8. contact shadow under standing objects
    if kind == "obj" and bw >= 6 and not name.startswith(NO_SHADOW) and y1 >= h - 3 and h - 1 > y1 - 1:
        # bottom-most opaque pixel of each column, shadow on the next transparent row(s)
        for x in range(x0, x1 + 1):
            col_m = np.nonzero(mask[:, x])[0]
            if len(col_m) == 0:
                continue
            yb = col_m.max()
            if yb < h - 3:
                continue
            for d, al in ((1, 0.30), (2, 0.14)):
                yv = yb + d
                if yv < h and out[yv, x, 3] < 0.05:
                    out[yv, x] = [0.04, 0.04, 0.10, al]
    return out


def _run(pk, kind):
    from common import Canvas
    new = []
    for name, cv in pk.items:
        arr = cv.a if hasattr(cv, "a") else cv
        if name.endswith("_glow") or name.startswith(SKIP_PREFIX):
            new.append((name, cv))
            continue
        if kind == "item" and (arr.shape[0] != 32 or arr.shape[1] != 32 or name.startswith(("ih_", "held", "wear", "coat_w"))):
            new.append((name, cv))
            continue
        new.append((name, Canvas.from_array(enhance(arr, name, kind))))
    pk.items = new


def finish_objects(pk):
    _run(pk, "obj")


def finish_items(pk):
    _run(pk, "item")
