"""In-hand sprites: every item icon shrunk to a crisp 12x12 for drawing in a character's hand.

Scaling a 32px icon on the GPU drops random pixels; this picks the dominant colour of each
block instead (so fine outlines don't eat small items) and then re-outlines the result.
Works on normal RGBA icons and on palette-encoded paper-doll icons (R = shade, G = material).
"""
from collections import Counter

import numpy as np

from common import Canvas, sel_outline

SIZE = 12
TARGET = 10  # longest side of the held sprite, leaving room for the outline


def _bbox(a):
    ys, xs = np.nonzero(a[:, :, 3] > 0.5)
    if len(ys) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def shrink(cv, encoded=False):
    a = cv.a
    bb = _bbox(a)
    out = Canvas(SIZE, SIZE)
    if bb is None:
        return out
    x0, y0, x1, y1 = bb
    bw, bh = x1 - x0, y1 - y0
    s = max(1.0, max(bw, bh) / TARGET)
    tw, th = max(1, int(round(bw / s))), max(1, int(round(bh / s)))
    ox, oy = (SIZE - tw) // 2, (SIZE - th) // 2
    for ty in range(th):
        for tx in range(tw):
            sx0, sx1 = x0 + int(tx * s), max(x0 + int(tx * s) + 1, x0 + int((tx + 1) * s))
            sy0, sy1 = y0 + int(ty * s), max(y0 + int(ty * s) + 1, y0 + int((ty + 1) * s))
            block = a[sy0:sy1, sx0:sx1].reshape(-1, 4)
            solid = block[block[:, 3] > 0.5]
            if len(solid) * 2.5 < len(block):
                continue
            if encoded:
                inner = solid[solid[:, 0] > 0.05]  # drop outline (shade 0) pixels
            else:
                luma = solid[:, :3] @ np.array([0.3, 0.55, 0.15])
                inner = solid[luma > 0.13]  # drop the dark outline
            pick = inner if len(inner) else solid
            key = Counter(tuple(np.round(p * 255).astype(int)) for p in pick).most_common(1)[0][0]
            out.a[oy + ty, ox + tx] = np.array(key) / 255.0
    if encoded:
        occ = out.a[:, :, 3] > 0.5
        res = out.a.copy()
        for y in range(SIZE):
            for x in range(SIZE):
                if occ[y, x]:
                    continue
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and occ[ny, nx]:
                        res[y, x] = [0, out.a[ny, nx, 1], 0, 1]
                        break
        out.a = res
    else:
        sel_outline(out, 0.55)
    return out
