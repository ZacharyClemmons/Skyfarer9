# Ships and world: performance pass

## How to measure
`./Skyfarer9_console.exe --path . -- --seed=42 --autotest=40 --sperf --flytest` prints once a second:
fps, worst frame, hitch count, then per-section ms/frame (n calls, max). Sections: FLEET, fly, ai,
parts, traffic(.spawn/.retire), spawn.*, weather, fauna(.wake/.drain/.sleep), climate, sweep,
restamp and rs.* / lay.* breakdowns. `~name` rows are frame slices between fixed process priorities
(they attribute time in systems we do not own). `--sperf` also lists islands with record counts,
useful for `--at=x,y`. Code: `src/sky/sperf.gd`. The engine's own `--perf` shows atmos/light.

## Before / after (flytest, seed 42, hull turning then flying)
| hotspot | before | after |
|---|---|---|
| frame rate while restamping | 13-17 fps, 280 ms hitches | 78-100 fps, no hitches |
| restamp (per tile step) | 3-4.4 ms | 0.5-1 ms |
| ambient light pass (`~light`) | 8-9 ms/frame | 0.4-0.7 ms/frame |
| atmos/other slice (`~default0`) | 75 ms/frame | 3-4 ms/frame |
| climate sweep (every 8 s) | 13 ms hitch | 2-3 ms, 3 islands/frame |
| traffic spawn provisioning | 9-21 ms | 1-1.4 ms |
| island wake (fauna) | whole island in one frame (up to ~4 ms+) | 1.5 ms/frame budget queue |

## What changed
- Restamp sends only tiles whose turf/structure/area/variant actually changed to atmos, chunk
  renderer and ambient light (was: every cell twice). Hull redraw skipped on slide/swing.
- Bug fix: `_fill_air` ran on EVERY restamp, resetting cabin air to 20C standard each tile
  (breaches, fires, cooked engine rooms erased by moving). Air is now snapshotted per local cell
  and set back where the hull lands; fresh air only at stamp/refit. LINDA fidelity is higher.
- Cached `shape_bounds()`, `sealed_cells()` (invalidated by mark_dirty); `center()`, `local_pivot()`
  and `visual_position()` no longer walk every cell per call.
- Incremental `ShipSystem.ship_tiles` (`claim_tiles`); `ship_at` is a dict lookup; `_fits` uses it.
- Ships more than 110 tiles away fly the same model in 0.1 s steps.
- FaunaStream queues spawns (budgeted per frame; dawn/dusk and sleep cancel stale jobs).
- Sky climate pass sliced; `Airship.set_modules` batches refits.
- Camera shimmer: removed 58 Hz hull jitter (beat against frame rate) and rounded `fx_offset` to whole pixels.
- Verified: gencheck clean, systemtest 31/0, flighttest 144/0.

## Remaining hotspots (ranked)
1. `ShipRenderer._carry` (render/) walks every hull cell and `Game.at` each frame per ship; make it
   event-driven (only carried entities). `lighting_system.gd:120` calls `ShipPlan.bounds` per ship: use `sh.shape_bounds()`.
2. Atmos `rebuild_edges` was 550 ms per dirty cycle; now incremental (other agent), re-check after ship moves.
3. `add_ship` ~5 ms per traffic spawn (stamp + fit-out entity creation): could spread over frames.
4. `Airship.mass()` scans cells x `e in parts` every 2 s per ship; use a parts id set.
5. `life` slice 1.2-1.7 ms (mobs), beast AI near islands: not profiled here.

## Ideas not done
Time-slice ShipAI `_look` for many ships; pool ShipRenderer/fittings for traffic; freeze far
ships' boilers/lift `process()` to a lower rate; pixel-snap camera in world_view; `Sfx._get`
signature error and `LineInFx` needed `--import` mid-session (other agents' files).
