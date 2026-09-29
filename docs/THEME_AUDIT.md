# Skyfarer theme and interrupted-work audit — 2026-09-29

The text pass changed player-facing job titles, departments, terrain names, item names and descriptions, window titles, duties, and messages from the old station setting to the sky-ship setting. The final round also changed the round-end heading to “The voyage is over.” Internal keys such as `station_map`, `spacecash`, `space_heater`, department IDs, sprite IDs, and save-file field names remain in place because gameplay and saved characters depend on them. Comments and unused legacy station-mode screens still contain station vocabulary; they do not appear in the Skyfarer opening.

The objects art generator now redraws station furniture and machinery as timber, brass, iron, canvas, and lanterns. The redraw preserves all 1,213 original `objects` manifest keys, sprite sizes, and atlas rectangles, including transparent legacy glow entries. Regenerating `objects` succeeds, and all six PNG sheets have valid dimensions and manifest rectangles. `build/.gdignore` keeps art backups out of Godot's import scan, eliminating duplicate resource-UID warnings.

The interrupted boarding work is finished: a reachable mooring is required for test ship launches and custom yard builds. The sloop has side-deck doors and access to the weather deck so it can be boarded. A failed custom launch refunds payment whether it was taken before or during commit. `--boardtest` passes 170 checks across stock and custom hulls at every tested yard.

The new sign-on office keeps the old slot fields and defaults missing new fields, so existing `characters.cfg` files load. `--chargentest` and `--introshot` run without writing character slots or XP; the intro driver was verified against an unchanged character-file hash. Headless screenshot drivers skip image capture because the dummy display server has no framebuffer. `--chargentest` passes.

Automated verification: import, generation, 44 system checks, 144 flight checks, 34 HUD checks, and 170 boarding checks passed after the changes above. Mouse-driven inventory and the final screenshot walkthrough are tracked in the run logs under `build/`.

The remaining work in `NEXT_session2_roadmap.md` is broader product work, including a first-hour human playthrough, manual animation/audio review, performance investigations, shallow outports, and region transit. Those items were not part of the four interrupted threads audited here.
