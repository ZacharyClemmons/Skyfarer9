"""Sky creature bodies.

Seven animated archetypes, drawn in the same palette-encoded form as the human paper doll
(R = shade, G = material) so `paperdoll.gdshader` recolours them from the four colours each
species carries in SkyMobs.BEASTS. That is the whole reason there are forty creatures in
the game and seven sprites here: a frost wolf and a mire hound are the same animation in
different coats, which is also true of actual wolves.

Materials: 0 body, 1 underside/limbs, 2 accent (eyes, markings, glow), 3 fixed dark (claws,
hooves, mandibles).

Each builder is `fn(d, f, z) -> Layer` for mobs.make_sheet: d is "s", "n" or "e" (west is
mirrored for us), f is the frame 0-2.
"""
import numpy as np

from common import T, ellipse_mask
from mobs import Layer, U, empty, m_rect

FRAMES = 3


def _ell(cx, cy, rx, ry):
    return ellipse_mask(T, T, cx, cy, rx, ry)


def _gait(f, a=1):
    """Two-beat walk cycle offset."""
    return {0: 0, 1: a, 2: -a}[f]


def _eyes(L, pts, mat=2, sh=5):
    for (x, y) in pts:
        L.set(x, y, mat, sh)


# ------------------------------------------------------------------ quadruped
def quad(d, f, z):
    """Wolf, hound, doe, stag, salamander: a body slung between four legs."""
    L = Layer()
    g = _gait(f)
    if d in ("s", "n"):
        body = _ell(16, 20, 7, 6)
        head = _ell(16, 12, 5, 4) if d == "s" else _ell(16, 12, 5, 4)
        legs = (m_rect(10, 24, 12, 29 - g) | m_rect(19, 24, 21, 29 + g)
                | m_rect(12, 25, 14, 29 + g) | m_rect(17, 25, 19, 29 - g))
        L.fill(legs, 1, base=2.6)
        L.fill(body, 0, base=3.4)
        L.fill(head, 0, base=3.8)
        if d == "s":
            _eyes(L, [(13, 11), (18, 11)])
            L.fill(m_rect(15, 14, 16, 15), 3, flat=True, base=2.0)  # muzzle
            # ears
            L.fill(m_rect(11, 8, 12, 10) | m_rect(19, 8, 20, 10), 1, base=3.0)
        else:
            L.fill(m_rect(11, 8, 12, 10) | m_rect(19, 8, 20, 10), 1, base=2.6)
            L.fill(m_rect(15, 24, 16, 28), 1, base=2.8)  # tail
    else:  # profile
        body = _ell(15, 19, 9, 5)
        head = _ell(23, 14, 4, 3)
        neck = m_rect(19, 14, 22, 19)
        legs = (m_rect(9, 23, 11, 29 + g) | m_rect(12, 23, 14, 29 - g)
                | m_rect(18, 23, 20, 29 - g) | m_rect(21, 23, 23, 29 + g))
        tail = m_rect(4, 15, 8, 17)
        L.fill(tail, 1, base=2.6)
        L.fill(legs, 1, base=2.6)
        L.fill(body, 0, base=3.4)
        L.fill(neck, 0, base=3.4)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(26, 14, 27, 16), 3, flat=True, base=2.0)  # snout
        L.fill(m_rect(21, 10, 22, 12), 1, base=3.0)  # ear
        _eyes(L, [(24, 13)])
    L.outline()
    return L


# ------------------------------------------------------------------ small scurrier
def small(d, f, z):
    """Hare, mite, tick, crab, leech: low, fast, and mostly body."""
    L = Layer()
    g = _gait(f)
    if d in ("s", "n"):
        body = _ell(16, 23, 6, 5)
        head = _ell(16, 17, 4, 3)
        L.fill(m_rect(11, 26, 13, 29 - g) | m_rect(19, 26, 21, 29 + g), 1, base=2.6)
        L.fill(body, 0, base=3.5)
        L.fill(head, 0, base=3.9)
        if d == "s":
            _eyes(L, [(14, 16), (18, 16)])
            L.fill(m_rect(13, 11, 14, 15) | m_rect(18, 11, 19, 15), 1, base=3.2)  # long ears
        else:
            L.fill(m_rect(13, 12, 14, 16) | m_rect(18, 12, 19, 16), 1, base=2.8)
    else:
        body = _ell(15, 23, 7, 5)
        head = _ell(22, 20, 4, 3)
        L.fill(m_rect(10, 26, 12, 29 + g) | m_rect(17, 26, 19, 29 - g), 1, base=2.6)
        L.fill(body, 0, base=3.5)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(19, 13, 20, 18), 1, base=3.2)
        L.fill(m_rect(8, 20, 10, 21), 1, base=2.8)  # scut
        _eyes(L, [(23, 19)])
    L.outline()
    return L


# ------------------------------------------------------------------ insect
def insect(d, f, z):
    """Mantis, beetle, shatterling: segmented, angular, too many joints."""
    L = Layer()
    g = _gait(f)
    if d in ("s", "n"):
        thorax = _ell(16, 20, 5, 6)
        abdomen = _ell(16, 26, 6, 4)
        head = _ell(16, 13, 4, 3)
        for side in (-1, 1):
            for k, yy in enumerate((17, 21, 25)):
                L.fill(m_rect(16 + side * 6, yy + (g if k == 1 else 0),
                              16 + side * 10, yy + 1 + (g if k == 1 else 0)), 3, base=2.4)
        L.fill(abdomen, 1, base=3.0)
        L.fill(thorax, 0, base=3.6)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(13, 9, 14, 12) | m_rect(18, 9, 19, 12), 3, base=2.6)  # antennae
        if d == "s":
            _eyes(L, [(14, 12), (18, 12)])
    else:
        thorax = _ell(15, 20, 6, 5)
        abdomen = _ell(8, 22, 6, 4)
        head = _ell(22, 16, 4, 3)
        for k, xx in enumerate((11, 16, 20)):
            L.fill(m_rect(xx, 24, xx + 1, 29 + (g if k == 1 else -g)), 3, base=2.4)
        L.fill(abdomen, 1, base=3.0)
        L.fill(thorax, 0, base=3.6)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(24, 11, 25, 14), 3, base=2.6)
        # raised forelimb, which is what makes a mantis a mantis
        L.fill(m_rect(24, 18, 28, 19) | m_rect(27, 14, 28, 18), 3, base=2.8)
        _eyes(L, [(23, 15)])
    L.outline()
    return L


# ------------------------------------------------------------------ flyer
def flyer(d, f, z):
    """Glidewing, moth, raptor: airborne, so it sits high in the frame with a shadow."""
    L = Layer()
    beat = {0: 0, 1: -3, 2: 2}[f]
    if d in ("s", "n"):
        body = _ell(16, 17, 3, 6)
        head = _ell(16, 11, 3, 3)
        for side in (-1, 1):
            wing = _ell(16 + side * 9, 15 + beat, 7, 4)
            L.fill(wing, 1, base=3.2)
        L.fill(body, 0, base=3.6)
        L.fill(head, 0, base=4.0)
        if d == "s":
            _eyes(L, [(14, 10), (18, 10)])
    else:
        body = _ell(15, 17, 6, 3)
        head = _ell(22, 15, 3, 3)
        L.fill(_ell(13, 14 + beat, 8, 4), 1, base=3.2)
        L.fill(body, 0, base=3.6)
        L.fill(head, 0, base=4.0)
        L.fill(m_rect(25, 15, 27, 16), 3, flat=True, base=2.2)  # beak
        L.fill(m_rect(6, 17, 9, 18), 1, base=2.8)  # tail
        _eyes(L, [(23, 14)])
    # the ground shadow that tells you it is not standing on anything
    L.fill(_ell(16, 29, 5, 2), 3, flat=True, base=1.0)
    L.outline()
    return L


# ------------------------------------------------------------------ drifter
def drift(d, f, z):
    """Wraith, wisp, spore cloud, the Quiet: no skeleton, no reliable outline."""
    L = Layer()
    pulse = {0: 0, 1: 1, 2: -1}[f]
    core = _ell(16, 17 + pulse, 7, 8)
    halo = _ell(16, 17 + pulse, 10, 11)
    # ragged skirt of trailing wisps
    skirt = empty()
    for i, x in enumerate((9, 12, 16, 20, 23)):
        h = 26 + ((i + f) % 3)
        skirt |= m_rect(x, 22, x + 1, h)
    L.fill(halo, 1, base=2.0, amp=0.8)
    L.fill(skirt, 1, base=2.2)
    L.fill(core, 0, base=3.4, amp=1.2)
    if d != "n":
        _eyes(L, [(13, 15 + pulse), (19, 15 + pulse)])
        L.set(13, 16 + pulse, 2, 4)
        L.set(19, 16 + pulse, 2, 4)
    L.outline()
    return L


# ------------------------------------------------------------------ biped
def biped(d, f, z):
    """Gargoyle, myconid, gravebound, golem: upright, and wrong about it."""
    L = Layer()
    g = _gait(f)
    if d in ("s", "n"):
        torso = _ell(16, 17, 6, 7)
        head = _ell(16, 8, 4, 4)
        arms = m_rect(8, 13, 10, 22 + g) | m_rect(21, 13, 23, 22 - g)
        legs = m_rect(12, 23, 15, 29 - g) | m_rect(16, 23, 19, 29 + g)
        L.fill(arms, 1, base=2.8)
        L.fill(legs, 1, base=2.8)
        L.fill(torso, 0, base=3.5)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(12, 28, 15, 29) | m_rect(16, 28, 19, 29), 3, base=2.2)
        if d == "s":
            _eyes(L, [(14, 8), (18, 8)])
            L.fill(m_rect(11, 12, 21, 13), 1, base=3.6)  # shoulders
        else:
            L.fill(m_rect(11, 12, 21, 13), 1, base=2.8)
    else:
        torso = _ell(16, 17, 5, 7)
        head = _ell(18, 8, 4, 4)
        L.fill(m_rect(15, 13, 17, 22 + g), 1, base=2.8)
        L.fill(m_rect(13, 23, 16, 29 - g) | m_rect(17, 23, 20, 29 + g), 1, base=2.8)
        L.fill(torso, 0, base=3.5)
        L.fill(head, 0, base=3.9)
        L.fill(m_rect(13, 28, 16, 29) | m_rect(17, 28, 20, 29), 3, base=2.2)
        _eyes(L, [(20, 8)])
    L.outline()
    return L


# ------------------------------------------------------------------ serpent
def worm(d, f, z):
    """Sand diver, crawler, lasher: a long body and no legs worth the name."""
    L = Layer()
    phase = f * 2
    body = empty()
    if d in ("s", "n"):
        # coiled, seen from above
        for i in range(6):
            x = 16 + int(6 * np.sin((i + phase) * 0.9))
            y = 10 + i * 3
            body |= _ell(x, y, 4 - i // 4, 3)
        head = _ell(16 + int(6 * np.sin(phase * 0.9)), 9, 4, 3)
        L.fill(body, 0, base=3.3)
        L.fill(head, 0, base=3.9)
        if d == "s":
            hx = 16 + int(6 * np.sin(phase * 0.9))
            _eyes(L, [(hx - 2, 8), (hx + 2, 8)])
            L.fill(m_rect(hx - 1, 11, hx + 1, 12), 3, flat=True, base=2.0)
    else:
        for i in range(7):
            x = 4 + i * 4
            y = 22 + int(3 * np.sin((i + phase) * 0.8))
            body |= _ell(x, y, 3, 3 - i // 5)
        head = _ell(28, 22 + int(3 * np.sin((7 + phase) * 0.8)), 4, 3)
        L.fill(body, 0, base=3.3)
        L.fill(head, 0, base=3.9)
        hy = 22 + int(3 * np.sin((7 + phase) * 0.8))
        L.fill(m_rect(29, hy, 31, hy + 1), 3, flat=True, base=2.0)
        _eyes(L, [(28, hy - 1)])
    L.outline()
    return L


ARCHETYPES = {
    "quad": quad,
    "small": small,
    "insect": insect,
    "flyer": flyer,
    "drift": drift,
    "biped": biped,
    "worm": worm,
}


def build_into(layers):
    """Add every archetype sheet to mobs.build's layer dict."""
    from mobs import make_sheet
    for name, fn in ARCHETYPES.items():
        layers[f"beast_{name}"] = make_sheet(fn)
