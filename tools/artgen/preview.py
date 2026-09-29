"""Composes a small mock scene from the generated sheets for eyeballing art.
Output goes to the path given as argv[1] (default: preview.png next to this file)."""
import json
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(__file__)
GFX = os.path.join(HERE, "..", "..", "assets", "gfx")
T = 32

man = json.load(open(os.path.join(GFX, "manifest.json")))
terrain = Image.open(os.path.join(GFX, "terrain.png"))


def tile(name):
    x, y = man["terrain"][name]
    return terrain.crop((x * T, y * T, x * T + T, y * T + T))


W, H = 22, 14
rng = random.Random(3)
grid = [["snow"] * W for _ in range(H)]
# rock outcrop
for y in range(0, 4):
    for x in range(0, 7 - y):
        grid[y][x] = "rock"
grid[1][2] = "rock_cryo"
# ice pond
for y in range(9, 13):
    for x in range(1, 6):
        grid[y][x] = "ice"
for x in range(6, 10):
    grid[7][x] = "packed"
# station block
for y in range(2, 12):
    for x in range(10, 21):
        edge = y in (2, 11) or x in (10, 20)
        grid[y][x] = "rwall" if edge else "floor_steel"
for y in range(3, 11):
    grid[y][15] = "wall"
grid[7][15] = "floor_steel"
for y in range(3, 11):
    for x in range(16, 20):
        grid[y][x] = "floor_white"
for x in (12, 13):
    grid[11][x] = "window"
grid[2][17] = "window"
grid[2][18] = "window"
grid[7][10] = "floor_dark"

img = Image.new("RGBA", (W * T, H * T))


def is_wallish(v):
    return v in ("rwall", "wall", "window")


def mask(x, y, pred):
    m = 0
    for bit, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0))):
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < H and pred(grid[ny][nx]):
            m |= bit
    return m


for y in range(H):
    for x in range(W):
        v = grid[y][x]
        base = f"snow_{rng.randint(0, 7)}"
        if v.startswith("floor") or v in ("wall", "rwall", "window"):
            base = f"{v}_{rng.randint(0, 3)}" if v.startswith("floor") else "plating_0"
        if v in ("ice", "packed"):
            base = f"{v}_{rng.randint(0, 3)}"
        img.alpha_composite(tile(base), (x * T, y * T))
        if v in ("ice", "packed"):
            m = mask(x, y, lambda k: k == "snow")
            if m:
                img.alpha_composite(tile(f"snowedge_{m}"), (x * T, y * T))
        if v.startswith("floor"):
            if y > 0 and is_wallish(grid[y - 1][x]) and grid[y - 1][x] != "window":
                img.alpha_composite(tile("ao_n"), (x * T, y * T))
        if v in ("rwall", "wall"):
            m = mask(x, y, lambda k: k in ("rwall", "wall"))
            img.alpha_composite(tile(f"{v}_{m}"), (x * T, y * T))
        if v == "window":
            m = mask(x, y, lambda k: k == "window")
            img.alpha_composite(tile(f"window_{m}"), (x * T, y * T))
        if v.startswith("rock"):
            m = mask(x, y, lambda k: k.startswith("rock"))
            name = f"{v}_{m}" + (f"_{rng.randint(0,2)}" if v == "rock" else "")
            img.alpha_composite(tile(name), (x * T, y * T))

# overlay other sheets if present
extra = []
for sheetname in ("objects", "items", "mobs"):
    p = os.path.join(GFX, f"{sheetname}.png")
    if os.path.exists(p) and sheetname in man:
        extra.append((sheetname, Image.open(p)))


def spr(sheetname, name, x, y):
    for sn, im in extra:
        if sn == sheetname and name in man[sheetname]:
            r = man[sheetname][name]
            w = r[2] if len(r) > 2 else T
            h = r[3] if len(r) > 3 else T
            img.alpha_composite(im.crop((r[0], r[1], r[0] + w, r[1] + h)), (x, y))


for (sheetname, name, x, y) in json.load(open(os.path.join(HERE, "preview_props.json"))) if os.path.exists(os.path.join(HERE, "preview_props.json")) else []:
    spr(sheetname, name, x, y)

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "preview.png")
img.resize((W * T * 2, H * T * 2), Image.NEAREST).save(out)
print(out)
