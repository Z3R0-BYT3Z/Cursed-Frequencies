# Cursed Frequencies v0.5.3

Cursed Frequencies is a server-authoritative Daily Curse system for Project Zomboid Build 42 multiplayer servers.

## Rotation

- Every curse and its intensity are randomized once on the server.
- A curse lasts 1, 2, or 3 real-world days, configurable through Sandbox Options.
- Curse identity, duration, intensity, timestamps, history, and event ID persist across restarts.
- The current and previous three curses are excluded when enough alternatives are available.
- At 06:00 local event time, the server activates a replacement or sends a morning reminder.
- At 18:00, it sends an evening reminder; the final evening is marked as an expiration warning.
- UTC offset defaults to `-4` for Eastern Daylight Time and should be changed to `-5` for Eastern Standard Time.

## F8 monitor

Players can press F8 (key code 66) to see the curse, intensity, description, duration, remaining time, frequency, event ID, and rotation state. Administrators additionally receive controls to reroll, select a curse, choose a 1-3 day duration, send a reminder, extend, shorten, pause, or resume rotation.

## Included curses

- Hollow Stomachs: hunger increases faster.
- Parched Earth: thirst increases faster.
- Sleepless Signal: fatigue increases faster.
- Heavy Air: periodic endurance pressure.
- Red Static: panic is periodically reinforced.
- Aching Bones: pain increases gradually.

Effects have Faint (0.75x), Active (1x), or Severe (1.25x) intensity. A configurable five-minute login/respawn grace period is enabled by default. Every effect stops being applied when its curse changes; persistent SandboxVars are never rewritten.

## Optional integrations

- Radio Frequencies (`MeeksRadio` v0.11.2): broadcasts through `MeeksRadio.ServerAPI.broadcast` at 102.8 MHz.
- Survivor League Community (`SurvivorLeagueCommunity` v1.8.6): may subscribe to lifecycle callbacks without modifying either mod's core.
- Discord: structured `[LostFrequencies]` log records include stable event IDs and exact timestamps.
- Global alerts appear in in-game server chat. Overhead alerts are optional and disabled by default.

## Installation

Extract the included `CursedFrequencies` folder into the local `Zomboid/mods` folder and add:

## Survivor League coexistence

Cursed Frequencies tracks exposure, kills, deaths, qualified survivors, cosmetic badges, and per-event results in its own `LostFrequenciesProfiles` ModData. It never writes to Survivor League season kills, lifetime kills, streaks, ranks, rewards, or migration data. Read-only status/API hooks allow a separately versioned Survivor League UI patch to render an F6 curse banner.

Rare beneficial anomalies have a five-percent selection chance. Performance-safe operation avoids population changes, loot edits, corpse scans, world scans, and continuous vehicle scans.

`Mods=ElixirCraftB42;MeeksRadio;SurvivorLeagueCommunity;CursedFrequencies`

Do not add a Workshop ID during localhost testing. Keep server and client copies identical.

## Integration API

```lua
LostFrequencies.ServerAPI.status()
LostFrequencies.ServerAPI.reroll("ADMIN", 2)
LostFrequencies.ServerAPI.setCurse("red_static", "ADMIN", 3)
LostFrequencies.ServerAPI.addListener("CurseActivated", callback)
```

Lifecycle events: `CurseActivated`, `CurseReminder`, `CurseExpiring`, `CurseEnded`, and `CurseChanged`.

## Verification checklist

1. Confirm the Cursed Frequencies Sandbox page loads without errors.
2. Confirm one activation appears on first start with a 1-3 day duration and intensity.
3. Press F8 as a player and as an administrator.
4. Confirm the login grace period prevents immediate stat changes.
5. Tune a powered radio to 102.8 MHz and confirm the bulletin appears.
6. Restart and confirm the same event ID, curse, intensity, and expiration persist.
7. Test each admin control and reconnect after every state change.
8. Temporarily set the activation/reminder hours near the current hour to verify daily deduplication.
9. Search logs for `[Cursed Frequencies]`, `[LostFrequencies]`, `ERROR`, and stack traces.
10. Confirm Radio Frequencies and Survivor League continue functioning on F7 and F6.
