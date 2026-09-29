# Render performance notes

## Measuring
`./Skyfarer9_console.exe --path . -- --seed=42 --autotest=15 --rperf --flytest` (also `--onisland`, `--day=0.77`).
`--rperf` prints every 4 s: fps, draw calls, objects, nodes, and avg/max/total-per-second ms for
`chunk_draw, ship_draw, snow_proc/draw, distant_draw, light_compose, light_fov, light_update,
light_ambient, light_proc_all, view_proc` (`WorldView.pt(key, t0)` is the helper; wrap any function).
Absolute fps is noisy (other work, atmos spikes of ~500 ms are outside render).

## Before -> after (same scenarios)
| item | before | after |
|---|---|---|
| terrain chunk _draw | 3.1 ms each (all 896 chunks at load = ~2.8 s) | 0.25-0.55 ms |
| lightmap compose | 3.7 ms x ~11/s, always | 1.15 ms, skipped when nothing changed (forced every 0.5 s) |
| FOV shadowcast | ~7 ms per player cell change | ~1.2 ms |
| snowfall | 0.63 ms/frame | 0.18 ms/frame |
| distant life draw | 0.21 ms/frame | 0.17 ms/frame |
| sky shader | full-res, all noise everywhere | half-res SubViewport, noise skipped where it cannot show |

## Changes
- terrain_chunk.gd: turf grid + predicate bits per chunk, int-keyed tile rect cache, pass 2/3 skipped when chunk has no pipes/cables/structures.
- world_view.gd: dirty chunks redrawn 3 per frame (queue) instead of all at once.
- lighting_system.gd: compose rewritten (row clipping, vis array, Image.convert float->half natively, ship overrides applied by iterating covered cells), skip-signature, inlined FOV opacity.
- sky_backdrop.gd / sky.gdshader: half-res render target (nearest upscale), early-outs for floor/decks.
- snowfall.gd: only live flakes updated, inline outdoor test. distant_life.gd: cached polygons.

## Remaining hotspots (ranked) / ideas
1. Entity node count (~8.6k nodes, ~2-3k objects/frame): cull/sleep offscreen entity sprites (not in my area).
2. atmos spikes (~500 ms) - sim owner.
3. Lighting: `_update_lights` loops all lights per frame; `_prepare_ship_lightmap` per compose; could move compose to a shader.
4. Chunks are redrawn on every hull restamp although terrain output is invariant under ship motion; safe to skip once verified.
5. Thermal/echo layers queue_redraw every 0.1 s even without the trait.
6. Sky: replace hash value-noise with a noise texture; update sky at lower rate when static.
7. Verify half-res sky at 2560x1440 visually; compare cloud-bank tiles A/B (flight screenshots differed by timing only).
