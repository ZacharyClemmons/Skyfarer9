"""Entry point: regenerates every sprite sheet and writes assets/gfx/manifest.json.

    py tools/artgen/gen.py            # everything
    py tools/artgen/gen.py tiles      # only some modules
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from common import OUT  # noqa: E402

MODULES = ["tiles", "objects", "items", "mobs", "fx", "ui"]


def main():
    want = sys.argv[1:] or MODULES
    path = os.path.join(OUT, "manifest.json")
    manifest = {}
    if os.path.exists(path):
        with open(path) as f:
            manifest = json.load(f)
    for m in want:
        mod = __import__(m)
        key = {"tiles": "terrain"}.get(m, m)
        manifest[key] = {}
        mod.build(manifest)
        print(f"built {m}: {len(manifest[key])} entries")
    with open(path, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
