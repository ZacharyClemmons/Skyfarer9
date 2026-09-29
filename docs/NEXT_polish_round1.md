# Next session: polish round 1 follow-ups

Written from the first five agents' hand-back reports (opening, shipyard UI, ship systems,
audio/UI feel, Port Meridian). Backup of `src/` from before any of this: `..\Skyfarer9_src_backup_1036`.
There is no git, so that copy is the only way back.

## Not verified by anyone (do these first)
- **Nobody has heard any of the sounds or watched any animation play.** Everything was checked by
  still screenshots and headless runs only. Play the first hour by hand.
- Shipyard **refit mode** (I on your own ship), the drag-stroke pitch rise, and the sounds were never exercised.
- The shipyard "Will she work" issues panel (`ShipPlan.diagnose` wiring) was **never rendered**. Check with
  `--yardshot --hullpick=sloop --purse=900 --yarddemo` then read `build/yard/shot_01.png`.
- Shop hover highlight and row highlight (needs a real mouse).
- Tutorial header font bump (11 -> 14) was not re-screenshotted.
- After the last edits, `--systemtest` and `--flighttest` were only confirmed by some agents; re-run all three
  (`--gencheck`, `--systemtest`, `--flighttest`) before trusting the build.

## Known open items
- Broker's shelf is empty, so its "What they have" tab shows nothing; only Sell has content.
- Blue dashed footprints on the ground come from `WorldView`; not touched.
- Message-log lines don't slide/fade in (single RichTextLabel); UI agent was asked to find an approach.
- Headless flighttest exit printed "6 ObjectDB instances were leaked"; unchecked whether it predates today.
- `UIFx` class was hand-added to `.godot/global_script_class_cache.cfg`; run `--import` once to regenerate cleanly.
- Three new class_names from Port Meridian (`PortLife`, `DistantLife`, `CloudBanks`) also need the import; already run once.

## Where things live (new today)
- Audio: `src/autoload/sfx.gd`, `sfx_ui.gd` (16 `ui_*` names + `ui_pop`, `ui_toast`; lazy-built, rate-limited).
- UI feel: `src/ui/ui_fx.gd` (`UIFx.toast/pop/shake/appear/ease_open/ease_close`; per-button opt-out `set_meta("no_fx", true)`).
- Opening: `src/ui/intro.gd`, `char_creator.gd`; flag `--introshot=DIR`.
- Shipyard: `src/ui/shipyard.gd`, `shipyard_art.gd`, `shipyard_fx.gd`; flags `--yarddemo[=stamp|launch|modules|book]`.
- Ship systems: `ShipPlan.diagnose/can_build/diagnose_text/components_of`, `CShipyard.refit_quote`,
  `Airship.effective_fittings`, arrival sequence (assigning `Game.fleet.player_ship`), `src/ui/ship_banner.gd`,
  `src/ship/ship_fx.gd`; flag `--arrivalshot`.
- Port: `src/sky/port_life.gd`, `src/render/distant_life.gd`, `src/render/cloud_banks.gd`, `hub.gd` layout changes;
  flags `--shopbuy`, `--shoptab=sell`.

## Ideas not done
- Real mixing pass on audio (levels between UI, ambience and engine) once someone can hear it.
- Outports still just three shops and a quay; give them Meridian-style life.
- Contracts/cargo/bounties still have nothing handing them out (see NOTES.md known gaps).
- Region transit between altitude bands is still a stub.
- 3D view doesn't draw the sky shader.

## Performance round
See `docs/NEXT_sim_perf.md`, `NEXT_render_perf.md`, `NEXT_ui.md`, `NEXT_ships_world.md`, `NEXT_qa.md`
(written by the agents that ran the performance and QA round).
