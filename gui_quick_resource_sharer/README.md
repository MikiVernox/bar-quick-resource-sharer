# Quick Ally Resource Sharer (Beyond All Reason Widget)

A high-performance Quality of Life (QoL) user-interface widget for Beyond All Reason (BAR). It continuously monitors your team's resource reserves (Metal and Energy), alerting you when an ally is critically stalling and enabling a single-click resource transfer when you hold a safe surplus.

---

## Why Use This Widget?

In large multiplayer matches (such as 8v8 on Supreme Strait, Glitter, or All Metal):
- **Frontline players** frequently face critical energy/metal stalls while repairing defenses, charging shields, or producing combat units.
- **Eco / Tech backline players** often sit on full resource storage with excessive overflow running to waste.
- **Existing UX bottleneck:** Opening the Diplomacy/F11 panel, searching for the teammate, dragging the resource slider, and pressing send requires multiple seconds of micro-attention and distracts from active combat.

### What This Widget Does:
1. **Detects Ally Stalls:** Scans teammate levels roughly once per second.
2. **Safety Surplus Check:** Prompts you only when your own storage is safely above reserve thresholds, preventing self-stalling.
3. **Discreet On-Screen Card:** Displays a semi-transparent HUD card with:
   - Ally name and missing resource ([E] Energy or [M] Metal).
   - Quick-transfer button (+500 E or +200 M) with real-time hover highlight.
   - Dismiss (x) button to snooze alerts for that teammate for 45 seconds.
4. **Interactive Repositioning:** Right-click or Middle-click drag allows you to position the card anywhere on your HUD.

---

## Fair Play & Competition Compliance

This widget strictly adheres to the official Beyond All Reason Code of Conduct (Section B.5 "Unfair Advantages"):

- **No Botting or Macro Automation:** Transfers never occur automatically. Every transaction requires an explicit, deliberate click by the player.
- **Zero Hidden Information:** Reads only team-level resource metrics that are already public and displayed to all allied players in the vanilla HUD.
- **Pure Client-Side (LuaUI):** Unsynced script execution with zero desync risk.
- **Spectator Safeguard:** Automatically deactivates when spectating.
- **Open Source:** Fully public and documented for Discord #widgets compliance.

---

## Performance & Optimization

Engineered specifically for high-tickrate Recoil / Spring RTS environments:
- **Zero Garbage Collection (GC) in Main Loop:** Uses an internal object pool (alertPool) to prevent frame-time GC spikes.
- **Fully Localized Engine Calls:** All Spring.*, gl.*, string.*, and math.* routines are localized to file scope for optimal LuaJIT dispatch.
- **Resolution-Aware:** Automatically adapts to screen resizing (widget:ViewResize) and clamps UI within view boundaries.
- **Cached String Allocation:** Player names and formatted identifiers are cached to eliminate runtime memory churn.

---

## Installation

1. Navigate to your local Beyond All Reason installation directory:
   - **Linux:** `~/.config/Beyond-All-Reason/data/LuaUI/Widgets/` or `~/.local/share/beyond-all-reason/data/LuaUI/Widgets/`
   - **Windows:** `%LocalAppData%\Programs\Beyond-All-Reason\data\LuaUI\Widgets\`
2. Place [gui_quick_resource_sharer.lua](LuaUI/Widgets/gui_quick_resource_sharer.lua) into your `LuaUI/Widgets/` folder.
3. In-game:
   - Press `F11` to open the widget manager and toggle **"Quick Ally Resource Sharer"**.
   - Alternatively, type `/luaui reload` in the in-game chat to instantly load new widgets without restarting.

---

## Configuration Reference

Edit the `CONFIG` table at the top of `gui_quick_resource_sharer.lua` to suit your preferences:

```lua
local CONFIG = {
  checkIntervalFrames   = 30,    -- Run scanner every ~1 second (30 sim frames)
  energyShareAmount     = 500,   -- Energy sent per click
  metalShareAmount      = 200,   -- Metal sent per click

  -- Ally stall detection criteria
  energyStallThreshold  = 100,   -- Minimum energy level triggering alert
  energyStallRatio      = 0.05,  -- Or below 5% of their total energy storage
  metalStallThreshold   = 50,    -- Minimum metal level triggering alert
  metalStallRatio       = 0.05,  -- Or below 5% of their total metal storage

  -- Local player minimum safety reserves (prevents self-stalling)
  myMinEnergyReserve    = 1000,
  myMinMetalReserve     = 400,

  -- Card dimensions & layout
  cardWidth             = 290,
  cardHeight            = 32,
  cardPadding           = 6,

  -- Snooze duration (in seconds) when clicking [x]
  snoozeDurationSec     = 45,

  -- Default position (pixels from bottom-left corner)
  defaultPosX           = 50,
  defaultPosY           = 520,
}
```

---

## Controls

| Action | Control |
| :--- | :--- |
| **Send Resources** | Left-Click on the `+500 E` or `+200 M` button |
| **Snooze / Dismiss** | Left-Click on the `x` button (mutes that ally's alerts for 45s) |
| **Reposition Card** | Right-Click or Middle-Click and drag anywhere on the alert card |

---

## License

Distributed under the GNU General Public License v2.0 or later (LICENSE).
