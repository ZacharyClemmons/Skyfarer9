# QA pass: first hour (creator -> intro -> yard -> launch -> fly)

## Fixed
- sfx.gd: `_get(name)` overrode Object._get (parse error, whole project failed to compile mid perf work). Renamed `_stream_of`.
- Intro card, opening chat line and tutorial claimed "near enough the price of a skiff". Only Deckhand (3,300) and Factor afford it (skiff = 3,203; other trades 2,376-2,772). Card now says how many marks short and points to the drawing board. Chronicle line used STARTING_PURSE instead of the real purse.
- ship_fx.gd: `live` puff budget was only decremented by a tween callback, so a freed fx layer could leave smoke stuck at MAX_LIVE. Now decremented on tree_exiting.
- Added `--refitdemo` (sky_main.gd) to exercise the refit path.

## Verified (logs clean, no SCRIPT ERROR)
introshot, arrivalshot, yarddemo=launch, refitdemo (refit charged, tile stamped), flytest, airtest, uishot, shopshot. gencheck, systemtest (31/0), flighttest (144/0).

## Open, ranked
1. Poorest trades (Prospector 2,376) may not afford even the leanest drawn hull (~2,500 by estimate); nothing else in the port earns marks quickly.
2. Ship banner and skill-up toast overlap the tutorial card at top centre right after launch.
3. Full berth refund path and "ashore/back" tutorial steps only read, not run. Tutorial "island" step can pass instantly if she is still alongside at home.
4. `--yardshot` opens the first yard found (an outport), not Meridian's.
5. characters.cfg is rewritten by --introshot.

## First-hour checklist
Creator (skip intro, pick each trade, sign on) -> card (press twice to skip) -> notice board -> yard desk -> buy/draw -> ESC mid-stamp -> launch -> banner -> boiler -> wheel -> throttle -> moor -> climb ashore -> back aboard.
