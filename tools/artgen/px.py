"""Second-generation pixel-art toolkit: volume shading from real surface normals, material
presets, and small hand-finishing helpers. Built on common.Canvas / ramps.

The idea is how a pixel artist shades by hand, done with maths:
  - every shape gets a height field (a bevel or a cylinder), its normals are lit from the
    upper left, and the light value is snapped onto a short hand-picked ramp;
  - each material adds what makes it read: metal gets a hard specular glint and dark
    reflections, plastic a soft highlight, glass is see-through with bright edge glints,
    cloth is matte with dithered folds, food is warm with soft rim light;
  - a darker hue-shifted outline, with the lit side softened, then a few manual touches.
"""
import numpy as np

from common import Canvas, hexc, mix, ramp, shade

LIGHT = np.array([-0.55, -0.7, 0.9])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
OUTLINE_DARK = hexc("#120f1a")


def _dist(mask):
    """Exact Euclidean distance (px) from each inside pixel to the nearest outside pixel
    (the canvas edge counts as outside)."""
    h, w = mask.shape
    pad = np.zeros((h + 2, w + 2), bool)
    pad[1:-1, 1:-1] = mask
    oy, ox = np.nonzero(~pad)
    d = np.zeros((h, w))
    iy, ix = np.nonzero(mask)
    if len(iy) == 0:
        return d
    # small canvases: brute force in chunks is plenty fast and exact
    for k in range(0, len(iy), 256):
        yy = iy[k:k + 256, None] + 1
        xx = ix[k:k + 256, None] + 1
        dd = np.sqrt((yy - oy[None, :]) ** 2 + (xx - ox[None, :]) ** 2).min(axis=1) - 0.5
        d[iy[k:k + 256], ix[k:k + 256]] = dd
    return d


def _blur(a):
    p = np.pad(a, 1, mode="edge")
    return (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + 4 * a) / 8.0


def _normals(height):
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def bevel_height(mask, bevel=3.0):
    d = _dist(mask)
    t = np.clip(d / bevel, 0, 1)
    return np.sin(t * np.pi / 2)  # rounded shoulder, flat top


def cyl_height(mask, axis="v"):
    """A cylinder across the shape: vertical axis (bottles, tanks) or horizontal."""
    h, w = mask.shape
    hgt = np.zeros((h, w))
    if axis == "v":
        for y in range(h):
            xs = np.nonzero(mask[y])[0]
            if len(xs):
                a, b = xs.min(), xs.max()
                c, r = (a + b) / 2, max(0.5, (b - a) / 2 + 0.5)
                for x in xs:
                    u = (x - c) / r
                    hgt[y, x] = np.sqrt(max(0, 1 - u * u)) * r
    else:
        for x in range(w):
            ys = np.nonzero(mask[:, x])[0]
            if len(ys):
                a, b = ys.min(), ys.max()
                c, r = (a + b) / 2, max(0.5, (b - a) / 2 + 0.5)
                for y in ys:
                    u = (y - c) / r
                    hgt[y, x] = np.sqrt(max(0, 1 - u * u)) * r
    return hgt


def sphere_height(mask):
    d = _dist(mask)
    r = max(1.0, d.max())
    t = np.clip(d / r, 0, 1)
    return np.sqrt(1 - (1 - t) ** 2) * r * 0.9


MATERIALS = {
    # tones in ramp, ramp spread, ambient, specular strength, specular sharpness
    "metal":   dict(n=6, spread=0.62, amb=0.18, spec=0.9, sharp=18, contrast=1.25),
    "chrome":  dict(n=7, spread=0.8, amb=0.10, spec=1.0, sharp=26, contrast=1.5),
    "paint":   dict(n=5, spread=0.5, amb=0.25, spec=0.45, sharp=10, contrast=1.05),
    "plastic": dict(n=5, spread=0.45, amb=0.3, spec=0.55, sharp=8, contrast=0.95),
    "rubber":  dict(n=4, spread=0.4, amb=0.3, spec=0.12, sharp=4, contrast=0.9),
    "cloth":   dict(n=5, spread=0.42, amb=0.35, spec=0.0, sharp=1, contrast=0.85),
    "paper":   dict(n=4, spread=0.28, amb=0.45, spec=0.0, sharp=1, contrast=0.7),
    "food":    dict(n=5, spread=0.48, amb=0.3, spec=0.35, sharp=6, contrast=1.0),
    "glass":   dict(n=5, spread=0.5, amb=0.2, spec=1.0, sharp=22, contrast=1.1),
    "organic": dict(n=5, spread=0.5, amb=0.28, spec=0.5, sharp=9, contrast=1.0),
}


def shade_mask(cv, mask, base, mat="paint", height=None, bevel=3.0, alpha=1.0, noise=0.0, seed=0, dither=False):
    """Fill `mask` with `base`, shaded as `mat` over a height field (bevel by default).
    Returns the ramp used (dark..light) so callers can pick matching detail colours."""
    m = MATERIALS[mat]
    base = hexc(base) if isinstance(base, str) else base
    pal = ramp(base, m["n"], m["spread"])
    if height is None:
        height = bevel_height(mask, bevel)
    n = _normals(_blur(height) * 1.6)
    diff = np.clip((n * LIGHT).sum(axis=2), 0, 1)
    view = np.array([0, 0, 1.0])
    hv = LIGHT + view
    hv /= np.linalg.norm(hv)
    spec = np.clip((n * hv).sum(axis=2), 0, 1) ** m["sharp"] * m["spec"]
    # a surface facing straight out of the screen shows the true base colour; facing the
    # light brightens it, facing away darkens it (never below the material's ambient)
    v = 0.5 + (diff - LIGHT[2]) * 1.5 * m["contrast"]
    v = np.maximum(v, m["amb"] * 0.6)
    if noise:
        rng = np.random.default_rng(seed)
        v = v + (rng.random(mask.shape) - 0.5) * noise
    v = np.clip(v, 0, 1)
    k = len(pal)
    f = v * (k - 1)
    if dither:
        # 2x2 ordered dither, only strong enough to break up the band edge between two tones
        yy, xx = np.mgrid[0:mask.shape[0], 0:mask.shape[1]]
        b2 = np.array([[0.0, 0.5], [0.75, 0.25]])[yy % 2, xx % 2]
        idx = np.floor(f + (b2 - 0.375) * 0.5 + 0.5).astype(int)
    else:
        idx = np.floor(f + 0.5).astype(int)
    idx = np.clip(idx, 0, k - 1)
    arr = np.array(pal)[idx]
    # specular glints: pure-ish white on metal and glass, tinted elsewhere
    hi = mix(pal[-1], hexc("#ffffff"), 0.75 if mat in ("metal", "chrome", "glass") else 0.35)
    sm = spec > 0.45
    arr[sm] = hi
    arr[..., 3] = alpha if mat != "glass" else alpha * 0.72
    if mat == "glass":
        arr[sm, 3] = 1.0
    cv.a[mask] = arr[mask]
    return pal


def outline(cv, soft_lit=True, strength=0.62):
    """Hue-shifted dark outline; pixels on the lit (upper-left) side get a lighter,
    softer outline so shapes don't look cut out."""
    a = cv.a
    h, w = a.shape[:2]
    alpha = a[:, :, 3] > 0.05
    out = a.copy()
    for y in range(h):
        for x in range(w):
            if alpha[y, x]:
                continue
            src = None
            lit = False
            for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx]:
                    src = a[ny, nx]
                    lit = dx > 0 or dy > 0  # the outline pixel sits up/left of the shape
                    break
            if src is None:
                continue
            c = shade(src, -strength)
            c = mix(c, OUTLINE_DARK, 0.62 if not (soft_lit and lit) else 0.38)
            c[3] = 1.0
            out[y, x] = c
    cv.a = out
    return cv


def shadow(cv, alpha=0.28):
    """Soft oval contact shadow under the item, for floor icons."""
    ys, xs = np.nonzero(cv.alpha_mask())
    if not len(ys):
        return cv
    bottom = min(cv.h - 1, ys.max() + 1)
    x0, x1 = xs.min(), xs.max()
    cx = (x0 + x1) / 2
    rx = max(2.0, (x1 - x0) / 2 * 0.8)
    under = Canvas(cv.w, cv.h)
    for y in (bottom - 1, bottom):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if 0 <= x < cv.w and 0 <= y < cv.h:
                fall = 1 - abs(x - cx) / (rx + 1)
                under.a[y, x] = [0.04, 0.04, 0.1, alpha * fall * (0.7 if y < bottom else 1.0)]
    under.paste(cv)
    cv.a = under.a
    return cv


def poly_mask(w, h, pts):
    """Filled polygon (even-odd) as a mask."""
    yy, xx = np.mgrid[0:h, 0:w]
    px_, py_ = xx + 0.5, yy + 0.5
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        cond = ((y0 > py_) != (y1 > py_)) & (px_ < (x1 - x0) * (py_ - y0) / ((y1 - y0) + 1e-9) + x0)
        inside ^= cond
    return inside


def capsule_mask(w, h, x0, y0, x1, y1, r):
    """A thick line with round ends (handles, shafts, tubes)."""
    yy, xx = np.mgrid[0:h, 0:w]
    px_, py_ = xx + 0.5, yy + 0.5
    ax, ay, bx, by = x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy or 1e-9
    t = np.clip(((px_ - ax) * dx + (py_ - ay) * dy) / L2, 0, 1)
    cx, cy = ax + t * dx, ay + t * dy
    return (px_ - cx) ** 2 + (py_ - cy) ** 2 <= r * r


def capsule_height(w, h, x0, y0, x1, y1, r):
    yy, xx = np.mgrid[0:h, 0:w]
    px_, py_ = xx + 0.5, yy + 0.5
    ax, ay, bx, by = x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy or 1e-9
    t = np.clip(((px_ - ax) * dx + (py_ - ay) * dy) / L2, 0, 1)
    cx, cy = ax + t * dx, ay + t * dy
    d2 = (px_ - cx) ** 2 + (py_ - cy) ** 2
    return np.sqrt(np.clip(r * r - d2, 0, None))


def rect_m(w, h, x0, y0, x1, y1, r=0):
    from common import rrect_mask
    return rrect_mask(w, h, x0, y0, x1, y1, r)


def ell_m(w, h, cx, cy, rx, ry):
    from common import ellipse_mask
    return ellipse_mask(w, h, cx, cy, rx, ry)


def finish(cv, floor=True, soft=True):
    outline(cv, soft)
    if floor:
        shadow(cv)
    return cv
