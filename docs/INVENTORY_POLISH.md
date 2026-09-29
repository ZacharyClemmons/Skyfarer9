# Inventory and opening polish

Press **Tab**, or click **Inventory [Tab]** above the equipment HUD, to open the inventory. The window shows a live character preview, both hands, every equipment slot, backpack and belt contents, storage capacity, and items at your feet.

- Drag items between hands, compatible equipment slots, and containers.
- Valid destinations glow green; an invalid hovered destination glows red.
- Drag onto the ground grid to drop at your current tile.
- Click a container or ground item to take it into a free hand.
- Right-click an item for its actions; Escape or right-click cancels a drag.
- Hover for the item's name, size and description.

Slots remain stable as contents change, including during a drag. Scroll clipping prevents hidden slots from accepting drops, and paused gameplay rejects transfers. Floating windows now sit above tutorial prompts.

The opening card wraps its body text, tutorial hints wrap and show progress, the arrival apron stays clear of quay clutter, and port traders wear trade-colored clothes and work accessories.

Compatibility is now the default renderer. During Vulkan checks, text and sprites intermittently disappeared after inventory transfers, including in the existing HUD. Compatibility rendered the same sequence correctly. This changes lighting/glow presentation; Vulkan remains available with `--rendering-method forward_plus` before the game's `--` arguments.

Run the mouse-driven inventory checks and capture previews with:

```powershell
.\Skyfarer9_console.exe --path . -- --autotest --seed=42 --inventorytest=build/polish
```

The existing control, tutorial and wildlife suite remains available through `--systemtest --seed=42`.
