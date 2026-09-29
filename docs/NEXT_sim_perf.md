# Sim performance notes

## How to measure
`Skyfarer9_console.exe --path . -- --seed=42 --autotest=40 --perf --flytest` (also `--onisland`).
`--perf` prints every 5 s: fps, worst dt, process ms, object/node/draw counts, then
`system=avg_ms/worst_ms` per system. Timers: `src/core/perf.gd` (`Perf.t0()` / `Perf.add(name, t)`),
wired into atmos (incl. a.* sub-parts), light, life, ai, power, director, evac.

## Before / after (--flytest, ms per frame avg / worst spike)
| system | before | after |
|---|---|---|
| atmos | 8-30 avg / 540-650 spike | 0.05-0.1 / 3-5 |
| everything else | life 1.2/9, ai 0.9/8, light 1-4/22 | unchanged (light 0.2/3 on foot) |

Cause: `AtmosSystem.rebuild_edges()` rescanned the whole 512x448 map (~230k tiles) every
time a moving airship changed a tile. Now it rescans only the 5x5 block around changed tiles
(`_edge_touched`), full scan once in `setup`. Verified identical to a full scan (0 mismatches).
`StationMap.add_blocker` now calls `Game.atmos.note_air_block(i)` because air-blocker changes
never emitted tile_changed.

## Remaining hotspots (ranked)
1. life ~1.1 ms avg, 8-40 ms spikes: per-second `life_tick` over all health entities plus
   `machines_tick` run in one frame; stagger across frames.
2. ai ~0.75 ms: every brain `act(d)` every frame; far-from-player brains could act less often.
3. light 3-4 ms spikes: `compose()` every 66 ms.
4. `objs` grows ~1000 per 5 s while nodes stay flat: likely leaked RefCounted/Resources. Not investigated.
5. process time 18-40 ms is mostly outside sim (render/ship/sky), not measured here.

## Not done
Time-slice life_tick; `all_with()` allocates `.values()` per call (about 30 per frame in life); skip far brains.
