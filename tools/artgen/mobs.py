"""Character paper-doll layers.

Every layer sheet is 96x128: columns = frames (idle, step A, step B), rows = dirs (S, N, E, W).
Pixels are *palette encoded* so the engine can recolour anything:
    R = shade index / 5   (0 = outline, 1 = darkest ... 5 = highlight)
    G = material / 3      (0 = primary, 1 = secondary, 2 = accent, 3 = fixed metal/dark)
The `paperdoll.gdshader` maps (material, shade) -> colour ramps supplied per garment.
"""
import numpy as np

from common import T, Canvas, edge_light, hexc, mix, rrect_mask, save, shade

DIRS = ["s", "n", "e", "w"]
FRAMES = 3


def m_rect(x0, y0, x1, y1, r=0):
    return rrect_mask(T, T, x0, y0, x1, y1, r)


def empty():
    return np.zeros((T, T), bool)


# ------------------------------------------------------------------ body geometry
def body_zones(d, f):
    """Returns dict of zone masks for direction d ('s','n','e') and frame f."""
    z = {}
    if d in ("s", "n"):
        z["head"] = m_rect(11, 3, 20, 12, 3)
        z["neck"] = m_rect(14, 12, 17, 13)
        z["torso"] = m_rect(11, 13, 20, 21, 1)
        la = 1 if f == 2 else 0  # arm swing (front view: arm drops 1px)
        ra = 1 if f == 1 else 0
        z["arm_l"] = m_rect(9, 14 + la, 10, 21 + la, 0) | m_rect(10, 13, 10, 14)
        z["arm_r"] = m_rect(21, 14 + ra, 22, 21 + ra, 0) | m_rect(21, 13, 21, 14)
        z["hand_l"] = m_rect(9, 22 + la, 10, 23 + la)
        z["hand_r"] = m_rect(21, 22 + ra, 22, 23 + ra)
        ll = 1 if f == 1 else 0
        rl = 1 if f == 2 else 0
        z["leg_l"] = m_rect(12, 21, 15, 27 - ll)
        z["leg_r"] = m_rect(16, 21, 19, 27 - rl)
        z["foot_l"] = m_rect(12, 28 - ll, 15, 29 - ll)
        z["foot_r"] = m_rect(16, 28 - rl, 19, 29 - rl)
    else:  # east facing profile; west is mirrored later
        z["head"] = m_rect(12, 3, 20, 12, 3) | m_rect(21, 8, 21, 9)  # nose
        z["neck"] = m_rect(15, 12, 17, 13)
        z["torso"] = m_rect(13, 13, 19, 21, 1)
        swing = {0: 0, 1: 2, 2: -2}[f]
        z["arm_l"] = empty()  # far arm hidden behind torso
        ax = 15 + (1 if swing > 0 else (-1 if swing < 0 else 0))
        z["arm_r"] = m_rect(ax, 14, ax + 2, 21, 0)
        z["hand_r"] = m_rect(ax + (1 if swing > 0 else 0), 22, ax + 2 + (1 if swing > 0 else 0) - 1, 23)
        z["hand_l"] = empty()
        if f == 0:
            z["leg_l"] = m_rect(14, 21, 18, 27)
            z["leg_r"] = empty()
            z["foot_l"] = m_rect(14, 28, 19, 29)
            z["foot_r"] = empty()
        else:
            front = 1 if f == 1 else -1
            z["leg_l"] = m_rect(15 + front * 2, 21, 17 + front * 2, 27) | m_rect(14, 21, 18, 23)
            z["leg_r"] = m_rect(15 - front * 2, 21, 17 - front * 2, 27)
            z["foot_l"] = m_rect(15 + front * 2, 28, 18 + front * 2, 29)
            z["foot_r"] = m_rect(15 - front * 2, 28, 18 - front * 2, 29)
    return z


def U(*ms):
    out = empty()
    for m in ms:
        out |= m
    return out


def expand(m, n=1):
    out = m.copy()
    for _ in range(n):
        o = out.copy()
        o[1:, :] |= out[:-1, :]
        o[:-1, :] |= out[1:, :]
        o[:, 1:] |= out[:, :-1]
        o[:, :-1] |= out[:, 1:]
        out = o
    return out


# ------------------------------------------------------------------ encoded layer canvas
class Layer:
    """Accumulates (material, shade) pixels for one frame."""

    def __init__(self):
        self.mat = np.full((T, T), -1)
        self.sh = np.zeros((T, T), int)

    def fill(self, mask, mat, light=(-1, -1), base=3.2, amp=1.6, extra=None, flat=False):
        lt = edge_light(mask, light) if not flat else np.zeros((T, T))
        f = base + lt * amp
        if extra is not None:
            f = f + extra
        s = np.clip(np.round(f), 1, 5).astype(int)
        self.mat[mask] = mat
        self.sh[mask] = s[mask]

    def set(self, x, y, mat, s):
        if 0 <= x < T and 0 <= y < T:
            self.mat[y, x] = mat
            self.sh[y, x] = s

    def darken(self, mask, amt=1):
        m = mask & (self.mat >= 0)
        self.sh[m] = np.clip(self.sh[m] - amt, 1, 5)

    def outline(self):
        occ = self.mat >= 0
        mat = self.mat.copy()
        sh = self.sh.copy()
        for y in range(T):
            for x in range(T):
                if occ[y, x]:
                    continue
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < T and 0 <= ny < T and occ[ny, nx]:
                        mat[y, x] = self.mat[ny, nx]
                        sh[y, x] = 0
                        break
        self.mat, self.sh = mat, sh

    def to_canvas(self):
        cv = Canvas()
        occ = self.mat >= 0
        cv.a[occ, 0] = self.sh[occ] / 5.0
        cv.a[occ, 1] = self.mat[occ] / 3.0
        cv.a[occ, 2] = 0
        cv.a[occ, 3] = 1
        return cv


def mirror(cv):
    return cv.flip_h()


def make_sheet(fn):
    """fn(d, f, zones) -> Layer or None. Builds the 96x128 sheet (W mirrors E)."""
    sheet = Canvas(T * FRAMES, T * 4)
    for di, d in enumerate(DIRS):
        for f in range(FRAMES):
            src_d = "e" if d == "w" else d
            z = body_zones(src_d, f)
            lay = fn(src_d, f, z)
            if lay is None:
                continue
            cv = lay.to_canvas()
            if d == "w":
                cv = mirror(cv)
            sheet.paste(cv, f * T, di * T)
    return sheet


# ------------------------------------------------------------------ layers
def body_layer(d, f, z):
    L = Layer()
    skin = U(z["head"], z["neck"], z["torso"], z["arm_l"], z["arm_r"], z["hand_l"], z["hand_r"],
             z["leg_l"], z["leg_r"], z["foot_l"], z["foot_r"])
    L.fill(z["torso"], 0)
    L.fill(z["neck"], 0, base=2.4)
    for k in ("leg_l", "leg_r"):
        L.fill(z[k], 0, base=3.0)
    for k in ("foot_l", "foot_r"):
        L.fill(z[k], 0, base=2.6)
    for k in ("arm_l", "arm_r", "hand_l", "hand_r"):
        if z[k].any():
            L.fill(z[k], 0, base=3.3)
    L.fill(z["head"], 0, base=3.4, amp=1.5)
    # underwear (material 1)
    under = U(z["leg_l"], z["leg_r"]) & m_rect(0, 21, 31, 23)
    L.fill(under, 1, base=3.0)
    if d == "s":
        # face details: mouth shadow, nose shading, cheek highlight
        L.set(15, 10, 0, 2)
        L.set(16, 10, 0, 2)
        L.set(15, 8, 0, 3)
        L.set(12, 9, 0, 4)
    if d == "e":
        L.set(20, 10, 0, 2)
        L.set(21, 9, 0, 3)
        L.set(18, 5, 0, 4)
    L.outline()
    return L


def eyes_layer(d, f, z):
    L = Layer()
    if d == "s":
        for x in (13, 18):
            L.set(x, 8, 0, 4)
            L.set(x, 7, 3, 1)  # brow (fixed dark, tinted by hair colour in engine via material 3 ramp)
    elif d == "e":
        L.set(19, 8, 0, 4)
        L.set(19, 7, 3, 1)
    return L


def hair_layer(style):
    def fn(d, f, z):
        L = Layer()
        head = z["head"]
        ys, xs = np.nonzero(head)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        m = empty()
        if style == "bald":
            return None
        if style in ("short", "sidepart", "spiky", "crew"):
            top = {"short": 3, "sidepart": 4, "spiky": 3, "crew": 2}[style]
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + top)
            if d == "n":
                m |= head & m_rect(0, 0, 31, y1 - 2)
            elif d == "e":
                m |= head & m_rect(0, 0, x0 + 4, y1 - 3)
            elif d == "s":
                m |= m_rect(x0 - 1, y0 + 2, x0, y0 + 5) | m_rect(x1, y0 + 2, x1 + 1, y0 + 5)
            if style == "spiky":
                for x in range(x0, x1 + 1, 2):
                    m |= m_rect(x, y0 - 2, x, y0 - 1)
            if style == "sidepart" and d == "s":
                m |= m_rect(x0, y0 + 3, x0 + 4, y0 + 4)
        elif style in ("long", "bob", "ponytail", "bun", "braids"):
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 3)
            length = {"long": 20, "bob": 13, "ponytail": 11, "bun": 11, "braids": 11}[style]
            if d == "s":
                m |= m_rect(x0 - 1, y0 + 1, x0 + 1, length)
                m |= m_rect(x1 - 1, y0 + 1, x1 + 1, length)
            elif d == "n":
                m |= expand(head, 1) & m_rect(0, 0, 31, 31)
                m |= m_rect(x0, y1, x1, length)
            else:
                m |= expand(head, 1) & m_rect(0, 0, x0 + 5, 31)
                m |= m_rect(x0 - 1, y0 + 2, x0 + 3, length)
            if style == "ponytail":
                if d == "n":
                    m |= m_rect(15, y1 - 1, 16, 18)
                elif d != "s":
                    m |= m_rect(x0 - 3, y0 + 3, x0 - 1, y0 + 12)
            if style == "bun":
                if d == "n" or d == "e":
                    bx = 15 if d == "n" else x0 - 1
                    m |= rrect_mask(T, T, bx - 1, y0 - 2, bx + 2, y0 + 1, 1)
                else:
                    m |= rrect_mask(T, T, 14, y0 - 3, 17, y0, 1)
            if style == "braids" and d in ("s", "n"):
                m |= m_rect(x0 - 1, y0 + 5, x0, 19) | m_rect(x1, y0 + 5, x1 + 1, 19)
        elif style == "afro":
            big = rrect_mask(T, T, x0 - 3, y0 - 3, x1 + 3, y0 + 7, 5)
            m |= big
            if d == "s":
                m &= ~m_rect(x0 + 1, y0 + 4, x1 - 1, 31)
            if d == "e":
                m &= ~m_rect(x0 + 5, y0 + 5, 31, 31)
        elif style == "mohawk":
            if d in ("s", "n"):
                m |= m_rect(14, y0 - 3, 17, y0 + 3)
                if d == "n":
                    m |= m_rect(14, y0, 17, y1 - 2)
            else:
                m |= m_rect(x0, y0 - 3, x1 - 2, y0 + 1)
        elif style == "buzz":
            m |= head & m_rect(0, 0, 31, y0 + 2)
            if d == "n":
                m |= head & m_rect(0, 0, 31, y1 - 2)
        elif style in ("undercut", "topknot"):
            # shaved sides; the undercut's long top is swept over to one side
            m |= head & m_rect(0, 0, 31, y0 + 1)
            if d == "n":
                m |= head & m_rect(0, 0, 31, y1 - 3)
            if style == "undercut":
                if d == "s":
                    m |= expand(head, 1) & m_rect(x0 - 1, 0, x1 - 2, y0 + 2)
                    m |= m_rect(x0, y0 + 2, x0 + 3, y0 + 4)
                elif d == "e":
                    m |= expand(head, 1) & m_rect(x0 - 1, 0, x1 - 1, y0 + 2)
                    m |= m_rect(x1 - 3, y0 - 1, x1, y0 + 1)
                else:
                    m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 2)
            else:
                m |= rrect_mask(T, T, 14, y0 - 4, 17, y0 - 1, 1)
        elif style in ("curly", "messy"):
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 3)
            if d == "n":
                m |= expand(head, 1) & m_rect(0, 0, 31, y1 - 2)
            elif d == "e":
                m |= expand(head, 1) & m_rect(0, 0, x0 + 4, y1 - 2)
            elif d == "s":
                m |= m_rect(x0 - 1, y0 + 2, x0, y0 + 6) | m_rect(x1, y0 + 2, x1 + 1, y0 + 6)
            # tufts along the top of the hair
            edge_top = y0 - 1
            for x in range(x0 - 1, x1 + 2):
                if style == "curly" and x % 2 == 0:
                    m |= m_rect(x, edge_top - 1, x, edge_top)
                if style == "messy" and (x * 7) % 5 in (0, 3):
                    m |= m_rect(x, edge_top - 2 if (x * 3) % 4 == 0 else edge_top - 1, x, edge_top)
            if style == "messy" and d == "s":
                m |= m_rect(x0 + 2, y0 + 2, x0 + 3, y0 + 4) | m_rect(x1 - 4, y0 + 2, x1 - 4, y0 + 3)
        elif style == "pigtails":
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 3)
            if d == "n":
                m |= expand(head, 1) & m_rect(0, 0, 31, y1 - 1)
            if d in ("s", "n"):
                m |= rrect_mask(T, T, x0 - 4, y0 + 2, x0 - 1, y0 + 9, 1)
                m |= rrect_mask(T, T, x1 + 1, y0 + 2, x1 + 4, y0 + 9, 1)
            else:
                m |= expand(head, 1) & m_rect(0, 0, x0 + 4, y1 - 3)
                m |= rrect_mask(T, T, x0 - 3, y0 + 2, x0, y0 + 9, 1)
        elif style == "slicked":
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 2)
            if d == "n":
                m |= expand(head, 1) & m_rect(0, 0, 31, y1 - 1)
            elif d == "e":
                m |= expand(head, 1) & m_rect(0, 0, x0 + 5, y1 - 2)
                m |= m_rect(x0 - 1, y0 + 4, x0, y0 + 7)
        elif style in ("shoulder", "dreads"):
            m |= expand(head, 1) & m_rect(0, 0, 31, y0 + 3)
            length = 15 if style == "shoulder" else 17
            if d == "s":
                m |= m_rect(x0 - 1, y0 + 1, x0 + 1, length)
                m |= m_rect(x1 - 1, y0 + 1, x1 + 1, length)
            elif d == "n":
                m |= expand(head, 1) & m_rect(0, 0, 31, 31)
                m |= m_rect(x0, y1, x1, length)
            else:
                m |= expand(head, 1) & m_rect(0, 0, x0 + 5, 31)
                m |= m_rect(x0 - 1, y0 + 2, x0 + 3, length)
            if style == "dreads":
                # ragged ends
                for x in range(0, T, 2):
                    m &= ~m_rect(x, length, x, length)
        if d == "s" and style not in ("afro", "mohawk"):
            # keep the face clear
            m &= ~m_rect(x0 + 2, y0 + 4, x1 - 2, y1)
        # strand shading: vertical stripes
        extra = np.zeros((T, T))
        for y in range(T):
            for x in range(T):
                if style == "dreads":
                    if x % 2 == 0:
                        extra[y, x] = -0.9
                elif style == "curly":
                    if (x + y) % 2 == 0:
                        extra[y, x] = -0.7
                elif style == "slicked":
                    if y % 3 == 0:
                        extra[y, x] = 0.5
                elif (x + (y // 3)) % 3 == 0:
                    extra[y, x] = -0.6
        L.fill(m, 0, base=3.2, amp=1.6, extra=extra)
        L.outline()
        return L
    return fn


def facial_hair(style):
    def fn(d, f, z):
        if d == "n":
            return None
        L = Layer()
        m = empty()
        base = 2.8
        if d == "s":
            if style == "beard":
                m |= m_rect(12, 9, 19, 12, 1) & ~m_rect(14, 10, 17, 10)
            elif style == "fullbeard":
                m |= m_rect(11, 7, 20, 14, 2) & ~m_rect(14, 10, 17, 10) & ~m_rect(12, 7, 19, 8)
            elif style == "mustache":
                m |= m_rect(14, 9, 17, 9)
            elif style == "handlebar":
                m |= m_rect(14, 9, 17, 9) | m_rect(12, 8, 13, 9) | m_rect(18, 8, 19, 9)
            elif style == "goatee":
                m |= m_rect(15, 11, 16, 12)
            elif style == "sideburns":
                m |= m_rect(11, 6, 11, 10) | m_rect(20, 6, 20, 10)
            elif style == "stubble":
                for x in range(12, 20):
                    for y in range(9, 13):
                        if (x + y) % 2 == 0 and not (14 <= x <= 17 and y == 10):
                            m[y, x] = True
                base = 2.2
        else:
            if style == "beard":
                m |= m_rect(15, 9, 20, 12, 1)
            elif style == "fullbeard":
                m |= m_rect(14, 8, 21, 14, 2) & ~m_rect(20, 8, 21, 8)
            elif style == "mustache":
                m |= m_rect(19, 9, 21, 9)
            elif style == "handlebar":
                m |= m_rect(19, 9, 21, 9) | m_rect(22, 8, 22, 8)
            elif style == "goatee":
                m |= m_rect(19, 11, 20, 12)
            elif style == "sideburns":
                m |= m_rect(14, 6, 15, 10)
            elif style == "stubble":
                for x in range(15, 21):
                    for y in range(9, 13):
                        if (x + y) % 2 == 0:
                            m[y, x] = True
                base = 2.2
        L.fill(m, 0, base=base, amp=1.0)
        return L
    return fn


def uniform(kind="jumpsuit"):
    def fn(d, f, z):
        L = Layer()
        arms = U(z["arm_l"], z["arm_r"])
        legs = U(z["leg_l"], z["leg_r"])
        torso = z["torso"]
        if kind == "skirt":
            skirt = rrect_mask(T, T, 11, 20, 20, 24, 1) if d != "e" else rrect_mask(T, T, 12, 20, 19, 24, 1)
            legs = skirt
        L.fill(legs, 0, base=2.8)
        L.fill(arms, 0, base=3.2)
        L.fill(torso, 0, base=3.3)
        # separation shadow between arms and torso
        L.darken(expand(arms, 1) & torso, 1)
        # collar & cuffs (secondary)
        if d == "s":
            for x in range(13, 19):
                L.set(x, 13, 1, 4 if x in (14, 17) else 3)
            L.set(15, 14, 1, 3)
            L.set(16, 14, 1, 3)
        elif d == "n":
            L.fill(m_rect(12, 13, 19, 13), 1, flat=True, base=3)
        else:
            L.fill(m_rect(15, 13, 18, 13), 1, flat=True, base=3)
        for k in ("arm_l", "arm_r"):
            if z[k].any():
                ys, xs = np.nonzero(z[k])
                L.fill(z[k] & m_rect(0, ys.max(), 31, ys.max()), 1, flat=True, base=3)
        # belt (accent)
        if kind != "scrubs":
            belt = torso & m_rect(0, 20, 31, 20)
            L.fill(belt, 2, flat=True, base=2)
            if d == "s":
                L.set(15, 20, 3, 5)
                L.set(16, 20, 3, 4)
        if kind == "formal" and d == "s":
            for y in range(15, 20, 2):
                L.set(15, y, 2, 5)
                L.set(16, y, 2, 4)
            # epaulettes
            L.set(10, 13, 2, 5)
            L.set(21, 13, 2, 5)
        if d == "s" and kind in ("jumpsuit", "formal"):
            # pocket
            L.set(18, 16, 1, 2)
            L.set(19, 16, 1, 2)
        L.outline()
        return L
    return fn


def shoes(d, f, z):
    L = Layer()
    m = U(z["foot_l"], z["foot_r"])
    m |= U(z["leg_l"], z["leg_r"]) & m_rect(0, 26, 31, 31)
    L.fill(m, 0, base=3.0, amp=1.3)
    L.outline()
    return L


def gloves(d, f, z):
    L = Layer()
    m = U(z["hand_l"], z["hand_r"])
    L.fill(m, 0, base=3.0, amp=1.2)
    return L


def coat(kind="winter"):
    def fn(d, f, z):
        L = Layer()
        arms = expand(U(z["arm_l"], z["arm_r"]), 0)
        torso = z["torso"]
        body = U(torso, arms)
        if kind in ("winter", "labcoat", "hazard"):
            hem = 25 if kind != "hazard" else 21
            # widen and lengthen
            if d in ("s", "n"):
                skirt = m_rect(11, 20, 20, hem)
            else:
                skirt = m_rect(13, 20, 19, hem)
            body = U(body, skirt)
            if kind == "winter":
                body = expand(body, 1) & ~m_rect(0, 0, 31, 12)
        elif kind == "armor":
            body = expand(torso, 1) & m_rect(0, 13, 31, 21)
        elif kind == "apron":
            body = torso & m_rect(12, 15, 19, 21) | (m_rect(12, 20, 19, 25) if d == "s" else empty())
            if d == "e":
                body = torso & m_rect(17, 14, 19, 21)
            if d == "n":
                body = m_rect(12, 17, 19, 17)
        L.fill(body, 0, base=3.2, amp=1.5)
        L.darken(expand(U(z["arm_l"], z["arm_r"]), 1) & torso & ~U(z["arm_l"], z["arm_r"]), 1)
        if kind == "winter":
            # fur trim: collar ring, hem, cuffs
            ys, xs = np.nonzero(body)
            fur = body & m_rect(0, ys.min(), 31, ys.min() + 1)
            fur |= body & m_rect(0, ys.max(), 31, ys.max())
            for k in ("arm_l", "arm_r"):
                if z[k].any():
                    ay = np.nonzero(z[k])[0].max()
                    fur |= expand(z[k], 1) & m_rect(0, ay, 31, ay)
            ex = np.zeros((T, T))
            ex[::2, ::2] = 0.6
            L.fill(fur, 1, base=4, amp=1, extra=ex)
            if d == "s":
                for y in range(15, 25):
                    L.set(15, y, 2, 2)
                    L.set(16, y, 2, 4)
                # pockets
                L.set(12, 22, 0, 1)
                L.set(13, 22, 0, 1)
                L.set(18, 22, 0, 1)
                L.set(19, 22, 0, 1)
        elif kind == "labcoat":
            if d == "s":
                for y in range(14, 26):
                    for x in (15, 16):
                        L.mat[y, x] = -1  # open front
                L.set(14, 14, 1, 4)
                L.set(17, 14, 1, 4)
        elif kind == "hazard":
            stripes = body & (m_rect(0, 16, 31, 16) | m_rect(0, 19, 31, 19))
            L.fill(stripes, 1, flat=True, base=5)
        elif kind == "armor":
            if d == "s":
                L.fill(m_rect(13, 15, 18, 17), 1, base=3.5, amp=1)
        L.outline()
        return L
    return fn


def headwear(kind):
    def fn(d, f, z):
        L = Layer()
        head = z["head"]
        ys, xs = np.nonzero(head)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        if d == "e":
            x1 = x1 - 1  # ignore nose
        if kind == "hood":
            m = expand(head, 1) & m_rect(0, 0, 31, y1 + 1)
            face = empty()
            if d == "s":
                face = rrect_mask(T, T, x0 + 2, y0 + 3, x1 - 2, y1, 2)
            elif d == "e":
                face = rrect_mask(T, T, x0 + 5, y0 + 3, x1 + 2, y1, 1)
            m &= ~face
            L.fill(m, 0, base=3.1)
            trim = expand(face, 1) & m
            ex = np.zeros((T, T))
            ex[::2, ::2] = 0.6
            L.fill(trim, 1, base=4, amp=0.8, extra=ex)
        elif kind == "beanie":
            m = expand(head, 1) & m_rect(0, 0, 31, y0 + 4)
            L.fill(m, 0, base=3.2)
            L.fill(m & m_rect(0, y0 + 3, 31, y0 + 4), 1, flat=True, base=3)
            L.fill(rrect_mask(T, T, 15, y0 - 3, 16, y0 - 2, 0), 2, base=4, amp=0.5)
        elif kind == "hardhat":
            m = rrect_mask(T, T, x0 - 1, y0 - 2, x1 + 1, y0 + 4, 3)
            m |= m_rect(x0 - 2, y0 + 4, x1 + 2, y0 + 4)
            L.fill(m, 0, base=3.4)
            if d == "s":
                L.fill(m_rect(14, y0, 17, y0 + 1), 2, base=5, flat=True)
        elif kind == "helmet":
            m = rrect_mask(T, T, x0 - 1, y0 - 2, x1 + 1, y0 + 5, 3)
            if d == "s":
                m |= m_rect(x0 - 1, y0 + 5, x0, y0 + 8) | m_rect(x1, y0 + 5, x1 + 1, y0 + 8)
            L.fill(m, 0, base=3.2)
            if d in ("s", "e"):
                vis = m_rect(x0 + (1 if d == "s" else 4), y0 + 4, x1 - (1 if d == "s" else -1), y0 + 5)
                L.fill(vis, 1, base=4, amp=0.8)
        elif kind == "welding":
            # a full face shield: the shell down over the face, a dark visor slot
            m = rrect_mask(T, T, x0 - 1, y0 - 2, x1 + 1, y0 + 9, 3)
            L.fill(m, 0, base=3.0)
            if d == "s":
                L.fill(m_rect(x0 + 1, y0 + 4, x1 - 1, y0 + 5), 1, flat=True, base=1)
                L.fill(m_rect(x0 + 1, y0 - 1, x1 - 1, y0 - 1), 2, flat=True, base=4)
            elif d in ("e", "w"):
                vx = x1 - 2 if d == "e" else x0
                L.fill(m_rect(vx, y0 + 4, vx + 2, y0 + 5), 1, flat=True, base=1)
        elif kind == "beret":
            m = rrect_mask(T, T, x0 - 1, y0 - 2, x1, y0 + 2, 2)
            L.fill(m, 0, base=3.0)
            L.set(x0 + 2, y0 + 1, 2, 5)
        elif kind == "cap":
            m = rrect_mask(T, T, x0, y0 - 1, x1, y0 + 3, 3)
            if d == "s":
                m |= m_rect(x0 + 1, y0 + 4, x1 - 1, y0 + 4)
            elif d == "e":
                m |= m_rect(x1 - 1, y0 + 3, x1 + 3, y0 + 3)
            L.fill(m, 0, base=3.2)
        elif kind == "chef":
            m = rrect_mask(T, T, x0, y0 - 5, x1, y0 + 2, 3)
            L.fill(m, 0, base=3.8, amp=1.2)
            L.fill(m & m_rect(0, y0 + 1, 31, y0 + 2), 1, flat=True, base=3)
        elif kind == "captain":
            m = rrect_mask(T, T, x0 - 1, y0 - 2, x1 + 1, y0 + 2, 2)
            if d == "s":
                m |= m_rect(x0, y0 + 3, x1, y0 + 3)
            L.fill(m, 0, base=3.0)
            L.fill(m & m_rect(0, y0 + 1, 31, y0 + 1), 2, flat=True, base=4)
            if d == "s":
                L.set(15, y0 - 1, 2, 5)
                L.set(16, y0 - 1, 2, 5)
        L.outline()
        return L
    return fn


def mask_layer(kind):
    def fn(d, f, z):
        L = Layer()
        if kind == "gasmask":
            if d == "s":
                m = rrect_mask(T, T, 12, 6, 19, 12, 2)
                L.fill(m, 0, base=2.8)
                for x in (13, 18):
                    L.set(x, 8, 1, 5)
                    L.set(x + (1 if x == 13 else -1), 8, 1, 4)
                L.fill(rrect_mask(T, T, 14, 11, 17, 13, 1), 3, base=3)
            elif d == "e":
                m = rrect_mask(T, T, 16, 6, 21, 12, 2)
                L.fill(m, 0, base=2.8)
                L.set(19, 8, 1, 5)
                L.fill(rrect_mask(T, T, 20, 10, 23, 12, 1), 3, base=3)
            else:
                L.fill(m_rect(11, 8, 20, 8), 3, flat=True, base=1)
        elif kind == "breath":
            if d == "s":
                L.fill(rrect_mask(T, T, 14, 9, 17, 11, 1), 0, base=3.5, amp=1)
            elif d == "e":
                L.fill(rrect_mask(T, T, 19, 9, 21, 11, 1), 0, base=3.5, amp=1)
        elif kind == "sunglasses":
            if d == "s":
                L.fill(m_rect(12, 7, 14, 8) | m_rect(17, 7, 19, 8), 0, base=1.5)
                L.fill(m_rect(15, 7, 16, 7), 0, flat=True, base=1)
            elif d == "e":
                L.fill(m_rect(18, 7, 21, 8), 0, base=1.5)
            elif d == "w":
                L.fill(m_rect(10, 7, 13, 8), 0, base=1.5)
        elif kind == "cigarette":
            if d == "s":
                L.fill(m_rect(16, 11, 18, 11), 0, flat=True, base=4)
                L.set(19, 11, 1, 4)
            elif d == "e":
                L.fill(m_rect(20, 11, 22, 11), 0, flat=True, base=4)
                L.set(23, 11, 1, 4)
            elif d == "w":
                L.fill(m_rect(9, 11, 11, 11), 0, flat=True, base=4)
                L.set(8, 11, 1, 4)
            return L
        elif kind == "scarf":
            if d in ("s", "n"):
                L.fill(m_rect(12, 12, 19, 14, 1), 0, base=3.2)
                if d == "s":
                    L.fill(m_rect(17, 14, 18, 19), 0, base=3)
                    L.fill(m_rect(17, 19, 18, 19), 1, flat=True, base=4)
                    L.fill(m_rect(12, 13, 19, 13), 1, flat=True, base=4)
            else:
                L.fill(m_rect(14, 12, 19, 14, 1), 0, base=3.2)
                L.fill(m_rect(12, 14, 13, 18), 0, base=3)
        L.outline()
        return L
    return fn


def backpack(d, f, z):
    L = Layer()
    if d == "n":
        L.fill(rrect_mask(T, T, 11, 14, 20, 23, 2), 0, base=3)
        L.fill(m_rect(12, 17, 19, 17), 1, flat=True, base=2)
        L.fill(m_rect(14, 19, 17, 21), 1, base=3, amp=1)
    elif d == "e":
        L.fill(rrect_mask(T, T, 10, 14, 13, 22, 1), 0, base=3)
    else:
        L.fill(m_rect(12, 13, 12, 18) | m_rect(19, 13, 19, 18), 0, flat=True, base=2)
    L.outline()
    return L


def toolbelt(d, f, z):
    L = Layer()
    t = z["torso"]
    L.fill(t & m_rect(0, 20, 31, 21), 0, flat=True, base=3)
    if d == "s":
        L.fill(m_rect(11, 21, 13, 23), 0, base=3, amp=1)
        L.fill(m_rect(18, 21, 20, 23), 0, base=3, amp=1)
        L.set(12, 22, 3, 5)
        L.set(19, 22, 3, 4)
    elif d == "e":
        L.fill(m_rect(12, 21, 14, 23), 0, base=3, amp=1)
    L.outline()
    return L


# ------------------------------------------------------------------ monkeys (tg species/monkey)
def monkey_zones(d, f):
    """A monkey: big head low on a short hunched body, long arms, short legs.
    Materials: 0 fur, 1 face/ears/palms, 2 bare skin (hands and feet)."""
    z = {}
    if d in ("s", "n"):
        z["head"] = m_rect(11, 9, 20, 17, 3)
        z["ears"] = m_rect(9, 12, 10, 14, 1) | m_rect(21, 12, 22, 14, 1)
        z["torso"] = m_rect(12, 17, 19, 24, 2)
        la = 1 if f == 2 else 0
        ra = 1 if f == 1 else 0
        z["arm_l"] = m_rect(10, 18 + la, 11, 25 + la)
        z["arm_r"] = m_rect(20, 18 + ra, 21, 25 + ra)
        z["hand_l"] = m_rect(10, 26 + la, 11, 26 + la)
        z["hand_r"] = m_rect(20, 26 + ra, 21, 26 + ra)
        ll = 1 if f == 1 else 0
        rl = 1 if f == 2 else 0
        z["leg_l"] = m_rect(12, 24, 14, 28 - ll)
        z["leg_r"] = m_rect(17, 24, 19, 28 - rl)
        z["foot_l"] = m_rect(12, 29 - ll, 14, 29 - ll)
        z["foot_r"] = m_rect(17, 29 - rl, 19, 29 - rl)
        z["face"] = m_rect(13, 12, 18, 16, 2) if d == "s" else empty()
    else:
        z["head"] = m_rect(12, 9, 19, 17, 3)
        z["ears"] = m_rect(13, 12, 14, 13)
        z["face"] = m_rect(17, 12, 21, 16, 2)
        z["torso"] = m_rect(13, 17, 19, 24, 2)
        swing = {0: 0, 1: 2, 2: -2}[f]
        ax = 16 + (1 if swing > 0 else (-1 if swing < 0 else 0))
        z["arm_l"] = empty()
        z["hand_l"] = empty()
        z["arm_r"] = m_rect(ax, 18, ax + 1, 25)
        z["hand_r"] = m_rect(ax + (1 if swing > 0 else 0), 26, ax + 1 + (1 if swing > 0 else 0), 26)
        if f == 0:
            z["leg_l"] = m_rect(14, 24, 17, 28)
            z["leg_r"] = empty()
            z["foot_l"] = m_rect(14, 29, 18, 29)
            z["foot_r"] = empty()
        else:
            front = 1 if f == 1 else -1
            z["leg_l"] = m_rect(15 + front, 24, 17 + front, 28)
            z["leg_r"] = m_rect(15 - front, 24, 17 - front, 28)
            z["foot_l"] = m_rect(15 + front, 29, 18 + front, 29)
            z["foot_r"] = m_rect(15 - front, 29, 18 - front, 29)
    return z


def monkey_body(d, f, _z):
    z = monkey_zones(d, f)
    L = Layer()
    L.fill(z["torso"], 0, base=3.0)
    for k in ("arm_l", "arm_r", "leg_l", "leg_r"):
        if z[k].any():
            L.fill(z[k], 0, base=3.1)
    L.fill(z["head"], 0, base=3.4, amp=1.5)
    L.fill(z["ears"], 1, base=3.0)
    if z["face"].any():
        L.fill(z["face"], 1, base=3.6, amp=1.0)
    for k in ("hand_l", "hand_r", "foot_l", "foot_r"):
        if z[k].any():
            L.fill(z[k], 2, base=2.8)
    if d == "s":
        # a lighter belly, the eyes (dark) and the nostrils
        L.fill(m_rect(14, 19, 17, 23, 1), 1, base=3.2, amp=0.6)
        for x in (14, 17):
            L.set(x, 13, 3, 1)
        L.set(15, 15, 1, 2)
        L.set(16, 15, 1, 2)
    elif d == "e":
        L.set(18, 13, 3, 1)
        L.set(21, 15, 1, 2)
    L.outline()
    return L


def monkey_tail(d, f, _z):
    """The tail curls out behind the monkey (drawn behind the body)."""
    L = Layer()
    wag = [0, 1, -1][f]
    if d == "s":
        pts = [(19, 23), (20, 24), (21, 24), (22, 23), (23, 22), (23, 21 + wag), (22, 20 + wag)]
    elif d == "n":
        pts = [(16, 24), (16, 25), (16, 26), (17, 27), (18, 27), (19, 26), (20, 25 + wag), (20, 24 + wag)]
    else:
        pts = [(13, 23), (12, 23), (11, 22), (10, 21), (10, 20 + wag), (11, 19 + wag)]
    for x, y in pts:
        L.set(x, y, 0, 3)
    L.outline()
    return L


# ------------------------------------------------------------------ mutation overlays (tg MUTATIONS_LAYER)
def _silhouette(d, f):
    z = body_zones(d, f)
    return U(*z.values())


def _aura(d, f, gap, step, mats=(0,), shades=(5, 4)):
    """A dotted ring hugging the body at `gap` pixels, shimmering between frames."""
    def ring():
        body = _silhouette(d, f)
        return expand(body, gap + 1) & ~expand(body, gap)
    L = Layer()
    r = ring()
    ys, xs = np.nonzero(r)
    for i, (y, x) in enumerate(zip(ys, xs)):
        if (x + y + f) % step:
            continue
        m = mats[(x // 2 + y // 2) % len(mats)]
        L.set(int(x), int(y), m, shades[(x + y) % len(shades)])
    return L


def mut_fire(d, f, _z):
    """tg fire (fiery sweat): flickers of flame licking up from the body."""
    L = Layer()
    body = _silhouette(d, f)
    edge = expand(body, 1) & ~body
    ys, xs = np.nonzero(edge)
    for y, x in zip(ys, xs):
        if (x * 3 + y + f * 5) % 7 < 2:
            for k in range(1 + (x + f) % 3):
                if y - k >= 0 and not body[y - k, x]:
                    L.set(int(x), int(y - k), 0 if k == 0 else 1, 5 - k)
    return L


def mut_antenna(d, f, _z):
    """tg antenna: a little stalk out of the top of the head with a red bulb."""
    L = Layer()
    x = 18 if d != "e" else 17
    for y in (1, 2):
        L.set(x, y, 0, 3)
    L.set(x, 0, 1, 5)
    L.set(x + 1, 0, 1, 4)
    L.outline()
    return L


def mut_lasereyes(d, f, _z):
    """tg laser eyes: the eyes glow red."""
    L = Layer()
    if d == "s":
        for x in (13, 18):
            L.set(x, 8, 0, 5)
            L.set(x, 7, 0, 3)
    elif d == "e":
        L.set(19, 8, 0, 5)
        L.set(20, 8, 0, 3)
    return L


def mut_telekinesishead(d, f, _z):
    """tg telekinesis: a shimmering halo around the head."""
    L = Layer()
    head = body_zones(d, f)["head"]
    r = expand(head, 2) & ~expand(head, 1)
    ys, xs = np.nonzero(r)
    for y, x in zip(ys, xs):
        if y <= 12 and (x + y + f) % 2 == 0:
            L.set(int(x), int(y), 0, 5 if (x + f) % 3 else 3)
    return L


MUTATIONS = {
    "mut_cold": lambda d, f, z: _aura(d, f, 1, 3),
    "mut_pressure": lambda d, f, z: _aura(d, f, 1, 4, shades=(4, 3)),
    "mut_radiation": lambda d, f, z: _aura(d, f, 0, 2, shades=(5, 4, 3)),
    "mut_thermal": lambda d, f, z: _aura(d, f, 1, 2, mats=(0, 1)),
    "mut_fire": mut_fire,
    "mut_antenna": mut_antenna,
    "mut_lasereyes": mut_lasereyes,
    "mut_telekinesishead": mut_telekinesishead,
}


# ------------------------------------------------------------------ preview colouriser (mirror of the shader)
def ramp6(hex_):
    b = hexc(hex_)
    return [mix(shade(b, -0.75), hexc("#14121c"), 0.5), shade(b, -0.45), shade(b, -0.22), b, shade(b, 0.2), shade(b, 0.42)]


def colourise(sheet, mats):
    out = sheet.copy()
    a = sheet.a
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            if a[y, x, 3] < 0.5:
                continue
            s = int(round(a[y, x, 0] * 5))
            m = int(round(a[y, x, 1] * 3))
            out.a[y, x] = ramp6(mats[min(m, len(mats) - 1)])[s]
    return out


HAIR = ["bald", "short", "crew", "buzz", "sidepart", "spiky", "long", "bob", "ponytail", "bun", "braids", "afro", "mohawk",
        "undercut", "topknot", "curly", "messy", "pigtails", "slicked", "shoulder", "dreads"]
FACIAL = ["beard", "mustache", "goatee", "fullbeard", "handlebar", "sideburns", "stubble"]
UNIFORMS = ["jumpsuit", "scrubs", "formal", "skirt"]
COATS = ["winter", "labcoat", "hazard", "armor", "apron"]
HATS = ["hood", "beanie", "hardhat", "helmet", "beret", "cap", "chef", "captain", "welding"]
MASKS = ["gasmask", "breath", "scarf", "sunglasses", "cigarette"]


def build(manifest):
    layers = {"body": make_sheet(body_layer), "eyes": make_sheet(eyes_layer),
              "shoes": make_sheet(shoes), "gloves": make_sheet(gloves),
              "backpack": make_sheet(backpack), "toolbelt": make_sheet(toolbelt),
              "monkey_body": make_sheet(monkey_body), "monkey_tail": make_sheet(monkey_tail)}
    for n, fn in MUTATIONS.items():
        layers[n] = make_sheet(fn)
    # Skyfarer: the seven creature archetypes, recoloured per species at runtime
    from sky_beasts import build_into as sky_beasts_build
    sky_beasts_build(layers)
    for h in HAIR:
        if h != "bald":
            layers[f"hair_{h}"] = make_sheet(hair_layer(h))
    for h in FACIAL:
        layers[f"facial_{h}"] = make_sheet(facial_hair(h))
    for u in UNIFORMS:
        layers[f"uniform_{u}"] = make_sheet(uniform(u))
    for c in COATS:
        layers[f"suit_{c}"] = make_sheet(coat(c))
    for hat in HATS:
        layers[f"head_{hat}"] = make_sheet(headwear(hat))
    for mk in MASKS:
        layers[f"mask_{mk}"] = make_sheet(mask_layer(mk))
    # one big atlas: each layer is a 96x128 block, 8 per row, then a strip of 32x32
    # clothing icons (same palette encoding, see wear_icons.py)
    from wear_icons import all_icons
    icons = all_icons()
    from inhands import shrink
    for n in list(icons):
        icons["held_" + n] = shrink(icons[n], encoded=True)
    names = sorted(layers)
    cols = 8
    rows = (len(names) + cols - 1) // cols
    icon_cols = 96 * cols // T
    icon_rows = (len(icons) + icon_cols - 1) // icon_cols
    atlas = Canvas(96 * cols, 128 * rows + T * icon_rows)
    for i, n in enumerate(names):
        atlas.paste(layers[n], (i % cols) * 96, (i // cols) * 128)
        manifest["mobs"][n] = [(i % cols) * 96, (i // cols) * 128, 96, 128]
    for i, n in enumerate(sorted(icons)):
        x, y = (i % icon_cols) * T, 128 * rows + (i // icon_cols) * T
        atlas.paste(icons[n], x, y)
        manifest["mobs"][n] = [x, y, icons[n].w, icons[n].h]
    save(atlas, "mobs.png")

    # colour preview for art review (not used by the game)
    def doll(parts):
        base = Canvas(96, 128)
        for name, mats in parts:
            base.paste(colourise(layers[name], mats))
        return base
    looks = [
        [("body", ["#e0ac8a", "#3a4a6a"]), ("eyes", ["#3a6ad8", "#000", "#000", "#3a2a1a"]), ("uniform_jumpsuit", ["#d8a53a", "#5f6878", "#3a3a40", "#9aa3b3"]),
         ("shoes", ["#3a3530"]), ("gloves", ["#d8c83a"]), ("toolbelt", ["#7a5a3a", "#000", "#000", "#b0b8c4"]), ("hair_short", ["#6a3a22"]), ("head_hardhat", ["#e8c83a", "#000", "#fff8d0"])],
        [("body", ["#8a5a3e", "#e8e8e8"]), ("eyes", ["#4a2a1a", "#000", "#000", "#1a1010"]), ("uniform_scrubs", ["#4aa3b8", "#e8eef4"]),
         ("shoes", ["#e8eef4"]), ("suit_labcoat", ["#eef2f6", "#4aa3d8"]), ("hair_ponytail", ["#1a1418"])],
        [("body", ["#f0c8a8", "#3a3a3a"]), ("eyes", ["#4a9a4a", "#000", "#000", "#c86a2a"]), ("uniform_jumpsuit", ["#8a2a33", "#2a2e38", "#1a1a20", "#b0b8c4"]),
         ("shoes", ["#1a1a20"]), ("suit_armor", ["#3a3f4a", "#5a6272"]), ("hair_crew", ["#c86a2a"]), ("head_helmet", ["#8a2a33", "#9fd0ec"]), ("facial_beard", ["#c86a2a"])],
        [("body", ["#c8906a", "#3a3a3a"]), ("eyes", ["#3a3a3a", "#000", "#000", "#1a1a1a"]), ("uniform_jumpsuit", ["#6a7486", "#9aa3b3", "#3a3a40", "#b0b8c4"]),
         ("shoes", ["#3a3530"]), ("suit_winter", ["#3a8a9a", "#efe8dc", "#c8ccd4"]), ("head_hood", ["#3a8a9a", "#efe8dc"]), ("mask_scarf", ["#c83a3a", "#f0e0c0"]), ("backpack", ["#5a6a3a", "#3a4a2a"])],
        [("body", ["#5a3a2a", "#e8e8e8"]), ("eyes", ["#3a2a1a", "#000", "#000", "#101010"]), ("uniform_formal", ["#2a3a6a", "#d8b84a", "#1a1a20", "#d8b84a"]),
         ("shoes", ["#1a1a20"]), ("hair_afro", ["#1a1418"]), ("head_captain", ["#2a3a6a", "#000", "#d8b84a"])],
        [("body", ["#f4d8c0", "#8a3a5a"]), ("eyes", ["#7a4ae8", "#000", "#000", "#e8c85a"]), ("uniform_skirt", ["#7a5ab8", "#e8eef4", "#3a3a40", "#b0b8c4"]),
         ("shoes", ["#3a3530"]), ("hair_long", ["#e8c85a"]), ("head_beanie", ["#d84a8a", "#f0e0e8", "#ffffff"])],
    ]
    samples = {"uniform": ["#d8a53a", "#5f6878", "#3a3a40"], "suit_winter": ["#3a8a9a", "#efe8dc", "#c8ccd4"], "suit_labcoat": ["#eef2f6", "#4aa3d8"],
               "suit_hazard": ["#e8803a", "#e8e8d0"], "suit_armor": ["#3a3f4a", "#5a6272"], "suit_apron": ["#e8eef4", "#8a93a3"], "head": ["#d84a4a", "#f0e0e0", "#ffffff"],
               "head_captain": ["#2a3a6a", "#000", "#d8b84a"], "head_hardhat": ["#e8c83a", "#000", "#fff8d0"], "mask": ["#5a6272", "#9fd0ec"], "mask_scarf": ["#c83a3a", "#f0e0c0"],
               "shoes": ["#3a3530"], "gloves": ["#d8c83a"], "backpack": ["#5a6a3a", "#3a4a2a"], "toolbelt": ["#7a5a3a"]}
    names_i = sorted(k for k in icons if not k.startswith("held_"))
    ip = Canvas(T * 9, T * ((len(names_i) + 8) // 9))
    for i, n in enumerate(names_i):
        key = n[5:]
        mats = samples.get(key) or samples.get(key.split("_")[0]) or ["#8a93a3", "#5f6878", "#3a3a40"]
        ip.paste(colourise(icons[n], mats), (i % 9) * T, (i // 9) * T)
    import os as _os
    from common import OUT as _OUT
    ip.image().resize((ip.w * 4, ip.h * 4), 0).save(_os.path.join(_OUT, "..", "..", "tools", "artgen", "icon_preview.png"))
    # every hairstyle and facial hair on the same head (S / E / N), for art review
    styles = [h for h in HAIR if h != "bald"] + ["f:" + f for f in FACIAL]
    hp = Canvas(T * 3 * 6, T * ((len(styles) + 5) // 6))
    for i, st in enumerate(styles):
        for k, row in enumerate((0, 2, 1)):
            for name, mats in [("body", ["#e0ac8a", "#3a4a6a"]), ("eyes", ["#3a6ad8", "#000", "#000", "#3a2a1a"]),
                               ("facial_" + st[2:] if st.startswith("f:") else "hair_" + st, ["#8a5a3a"])]:
                full = colourise(layers[name], mats)
                hp.paste(Canvas.from_array(full.a[row * T:row * T + T, 0:T].copy()), (i % 6) * T * 3 + k * T, (i // 6) * T)
    import os as _os2
    from common import OUT as _OUT2
    hp.image().resize((hp.w * 3, hp.h * 3), 0).save(_os2.path.join(_OUT2, "..", "..", "tools", "artgen", "hair_preview.png"))
    prev = Canvas(96 * len(looks), 128)
    for i, lk in enumerate(looks):
        prev.paste(doll(lk), i * 96, 0)
    import os
    from common import OUT
    prev.image().resize((96 * len(looks) * 3, 128 * 3), 0).save(os.path.join(OUT, "..", "..", "tools", "artgen", "mob_preview.png"))
