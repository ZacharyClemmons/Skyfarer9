# UI performance and polish pass

## Run the profiler
`godot --path . -- --autotest=16 --onisland --uiperf` (add `--yardshot --hullpick=sloop --yarddemo`
for the yard). Every 5 s it prints ms/frame per key (`UIPerf`, src/ui/ui_perf.gd) and how many
processing nodes sit under the HUD. Wrap new hot code with `UIPerf.t0()` / `UIPerf.end(key, t)`.

## Measured
- HUD script cost is small: about 0.2 ms/frame (hover 0.10-0.15, screenfx 0.06, status 0.02).
- Yard: `_draw_board` about 3 ms per redraw, redrawn every frame. Now 30 Hz when idle.
- Autotest fps dropped 99 to 12 (engine process about 560 ms) after about 5 s. It is identical with
  `--hidehud`, so it is world/sim, not UI. Someone should profile that.
- Sfx: `ui_launch` 185 ms, `ui_stinger` 112 ms, `ui_purchase` 26 ms, body voices 1-40 ms each,
  all synthesised on first click. Now built on a worker thread at startup.

## Fixed
- Screen-fx shader read the screen texture every frame (full back-buffer copy) for just a vignette.
  A stripped copy runs unless blur/mono/psychic is active; uniforms are only sent on change.
- HUD overlay redraw only while do-afters or AI debug are active.
- Message log: a repeated line used to rebuild all 2000 lines, and so did every line past the
  cap. Both now patch one paragraph. New lines slide and fade in (`LineInFx`).
- Clock plaque was pinned 820 px wide, running under the tutorial card. It now fits its text.
- Tutorial card cached its word wrap and redraws only while animating.
- Yard: bill/purse labels no longer set text and colour overrides every frame; StatRow only
  processes while animating.
- Powers bar, target doll, heartbeat tooltip and the Cooldown widget throttled.
- `ui_ding` and `ui_select` were silent (unknown names). They are aliased now.

## Still open
- The shop, notice, skill and craft screenshots were not reviewed for clipping or overflow at
  1280x720 and 2560x1440.
- Window drag-off-screen, Esc behaviour and focus after clicking UI were not audited.
- `UIWindow._process` runs `_fit_height`, `_clamp` and `get_combined_minimum_size` every frame for
  each open window.
- Helm panel and ship-panel gauges redraw every frame while flying.
- Number tick-ups exist in the yard only. The HUD purse and shop totals do not tick.

# Readability / settings pass
- **HUD scale**: `HUD.apply_ui_scale()` scales the HUD and window canvas layers (not the world). Auto (default) keeps
  text the same size on screen as at 1920x1080, capped at 1.25; Settings > HUD scale overrides. `root` and `windows` are
  sized by hand (viewport / scale). Screen positions must go through `HUD.to_ui()`; `over_hud(pos)` and `_drop_target`
  already do. Text outside the canvas layers (tooltips, popup menus, toasts) uses `UITheme.px()`.
- **Settings window** (F9, the cog, or Settings on the pause menu): `src/ui/settings_menu.gd` (no class_name on purpose).
  HUD scale, panel opacity, graphics quality (`LightingSystem.quality`; High bloom needs a relaunch), fullscreen, vsync,
  frame cap, log text size, idle-fade, worn-gear slots, master volume, key rebinding (InputMap actions only; Q/E/Space/G
  are hard-coded). Everything persists in `user://prefs.cfg` (`UITheme.save_pref`) and is re-applied by
  `SettingsMenu.apply_saved()`.
- HUD: the purse is its own line and counts up/down (`_tick_purse`); the message log folds its tabs and dims after ~6 s
  idle (`_update_chat_fade`); the worn-gear grid is folded behind a "Worn" button; the hands panel slides sideways when
  it would hit the vitals panel (`_dodge_hands`); clicking a button/slider releases keyboard focus; clicking away from a
  text box releases it too.
- `UITheme.label()` never draws under 14 px. Focus ring, slider theme, label shadows, icon-button tooltips (`TipButton`).
- Test hooks: `--hudtest` (34 checks, prints HUDTEST), `--uiscale=1.3`, `--settingsshot`, `--logshot`, `--tipshot`.
- Not verified by a human: mouse drags, real tooltips on hover, key capture with a physical keyboard, audio, animation.
