# Next session: roadmap after the graphics / UI / theming round (2026-09-29)

No git. Backups of `src/`: `..\Skyfarer9_src_backup_0929` (before polish round 2) and
`..\Skyfarer9_src_backup_graphics1` (before the graphics round). Art backups: `build/props_pre/`,
`build/theme_pre/` (if the sprite agent got that far), `build/terrain_pre_g1.png`.

**Use `.\Skyfarer9_console.exe`, not the PATH `godot_console`** (the PATH one is the mono build and prints
".NET: Assemblies not found" on every boot). Screenshots need `--autotest=N --shots=DIR`; shot_00 is black.

## FIRST THING NEXT SESSION: state of the tree is not confirmed
Several agents were still running or were killed mid-work when usage ran low (auto-mode safety check went down).
1. Run `Skyfarer9_console.exe --headless --path . --import` and READ the full output. The very first import
   printed a C++ backtrace (from the mono build); never confirmed the import itself finished.
2. Run `--gencheck`, `--systemtest` (44 checks), `--flighttest` (144), `--hudtest` (34). All were 0 failed
   at each agent's last report, but the tree was being edited concurrently afterwards.
3. Check for half-finished work from the four agents below.

## Agents that were interrupted (check their files)
- **Boarding / spawn reachability test (killed).** NOTHING is proven about mounting/dismounting ships.
  `ui/shipyard.gd:_stamp_custom` puts a built ship at `yard.berth` alongside the quay, and if it does not fit
  it walks her out 1..19 tiles into open sky, or returns null. Risk: a big hull can end up off the quay and
  unreachable on foot; or null after the player has paid. May have left a partial `--boardtest` in `src/debug/`.
  TODO: write `--boardtest` (every book hull + odd custom hulls: walk quay -> deck and back, via the game's
  real walkability), fix whatever it finds (gangway tile, better berth choice, refuse+refund on failure).
- **Sprite theming + props redraw (killed, said "Retrying the write").** Check `assets/gfx/*.png` and
  `manifest.json` are consistent; restore from `build/theme_pre/` / `build/props_pre/` if not.
  Goal: remove SS13 look (chrome consoles, vending machines, hazard-stripe doors, jumpsuits) in favour of
  brass / riveted iron / oak / canvas / lanterns. Keep sizes, anchors, manifest keys unchanged.
- **Theme text audit (may still be running/incomplete).** Should have written `docs/THEME_AUDIT.md`.
  Display strings only; never rename internal IDs. Re-run all tests since some check exact strings.
- **Character creator overhaul (may still be running/incomplete).** Files: `src/ui/char_creator.gd`,
  `src/ui/chargen/*`, `src/ui/intro.gd`. `--introshot` rewrites `characters.cfg`: verify the user's saved
  characters were not clobbered. Must keep: trade purse vs skiff price logic, intro card "short"/"near enough"
  text (tested in `src/debug/sky_polish_test.gd`), saved-character compatibility.

## Done this session (all reported 0 failed on the three core tests)
- Ships/world: broker shelf stocked (`comp/c_vendor.gd`), outports get lanterns + quay clutter (`sky/hub.gd`).
- UI: "Will she work" panel verified + "Nothing wrong with her." bug fixed; refit verified; tutorial header
  clip fixed; `UIWindow._process` throttled. New Settings window (F9): HUD scale, text size, opacity,
  fullscreen/vsync/fps cap, master volume, key rebinding (~30 actions), graphics quality. HUD declutter
  (log idle-fade, Worn button), purse count-up, bigger log text, tooltips, F1 help rewritten.
  New flags: `--hudtest --uiscale=N --settingsshot --logshot --tipshot --refitdemo=hold`.
- Lighting: unseen deck is a dim shade not black; AO; time-of-day grade; lamp glow (high); `--gfx=low|medium|high`
  (`LightingSystem.quality`, default medium; settings menu sets it, High bloom only applies next launch).
- Sky: `sky.gdshader` rewritten (pixel-snapped, dithered, lit parallax clouds, distant islands, stars/moon/
  aurora), 3D sky in `render3d/view3d.gd`. About 1.4 ms/frame.
- Ground/materials: flagstone dock, planked decks, hull seams, ground shader with cloud shadows + wind,
  `ship_flair.gd` (ensign, jack, stay rope, ship shadow), `ambient_motes.gd`. Toggles `--noshader --nomotes --noflair`.
- Props: `tools/artgen/props_fx.py` finishing pass (outlines, rims, glints, grime, contact shadows); lamp/boiler
  glow flicker in `core/entity.gd`. Moderate improvement only.
- Perf: life_tick sliced across frames; far AI brains every 4th frame; vision layers redraw only when needed.
- QA: `--systemtest` 44 checks incl. intro-card text vs skiff price, ship_fx puff budget.

## Known open problems
- **Object count grows ~1,100 per 5 s** (non-node, non-resource, probably RefCounted). Disabling 13 `_process`
  callbacks together stops it, neither half alone: at least two sources. Not found.
- **ObjectDB "instances were leaked" at exit** is intermittent (6/10/12/14 seen), never reproduces with `--verbose`.
- Script errors seen mid-run from UI edits in flux ("StyleBoxFlat to StyleBoxTexture", "pressed on Nil",
  compile cascade `load_prefs`/`focus_ring`/`_extend_theme`) and "previously freed" errors from
  `ShipSystem._motion_feel`, `SkySystem._wind`, `HelmPanel._process` during yard-demo teardown. Re-check after
  everything settles.
- Blocky square patches around ships come from the ship lightmap (`ship_lightmap.gdshader`), not the sky.
- Poorest trade purse 2376 vs cheapest hull 3175: Prospector cannot afford any book hull (open question:
  can they afford a hull they draw themselves?).
- Ship controls (Q/E ballast, Space, G, R) are hard-coded in `player_controller.gd`; cannot be rebound.
- HUD scale above ~1.3 can overlap bottom panels on small windows.
- Boiler gauge needle + steam wisps not done (need animation frames). Creatures/characters art untouched.
- Not done from earlier: outports still shallow, contracts/cargo/bounties have no giver, region transit stub,
  `Airship.mass()`, `ShipRenderer._carry` rewrite, real bloom (glow is faked in the lightmap).

## Nobody has verified (needs a human at the keyboard)
Sounds, all animation (clouds, flags, flicker, fireflies, purse count, log fade), every mouse interaction
(sliders, hover, drag/drop, right-click menus at scale, Settings buttons), key capture, 2560x1440 feel,
boarding a ship by hand, glow alignment on a rotating hull, water/lava/grass biome looks, 3D view at night,
storm skies. Play the first hour by hand.

## Ideas
- Second props pass by hand-redrawn key sprites: helm wheel, boiler, sea-chests, port stalls.
- Mixing pass on audio once someone can hear it.
- Screen-space bloom behind a High-quality toggle (needs backbuffer copy; currently avoided for perf).
- Perf: sky noise texture, lower sky update rate, lighting compose to a shader.
