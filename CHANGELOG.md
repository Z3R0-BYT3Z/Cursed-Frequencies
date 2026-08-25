# Changelog

## v0.5.3

- Increased the cursed-signal HUD indicator to the vanilla 64x64 moodle footprint.
- Removed the four-pixel internal inset so it aligns with the adjacent top moodle.
- Preserved the separate column that prevents overlap with vanilla moodles.
- Bumped the client/server protocol to reject mixed v0.5.2 and v0.5.3 installs.

## v0.5.2

- Moved the cursed-signal indicator out of the vanilla moodle column.
- Prevented overlapping hover targets and simultaneous tooltip bars.
- Restored the intended skull, radio tower, and magenta-static moodle artwork.
- Bumped the client/server protocol to reject mixed v0.5.1 and v0.5.2 installs.

## v0.5.1

- Global curse alerts now appear in in-game server chat.
- Added optional overhead alerts, disabled by default.
- Clarified non-environmental curses as `NOT WEATHER-BASED` instead of `NATURAL`.
- Preserved Radio Frequencies delivery and persistent station bulletin history.
- Corrected the root manifest version and bumped the handshake protocol to reject mixed installs.

## v0.5.0

- Added Black Sky, Tropical Static, Whiteout, Dead Air, and Eye of the Storm signals.
- Added server-authoritative storm, tropical-storm, and blizzard weather stages.
- Added persistent weather ownership with safe cleanup after expiration, rerolls, or disabling the mod.
- Added live administrator weather stop and restore controls.
- Added environmental weather and Radio Frequencies status to Current Signal.
- Added optional Radio Frequencies broadcasts with persistent duplicate-delivery prevention.
- Added environmental sandbox settings and outdoor-only penalties.
- Updated the client/server protocol to version 4.

## v0.4.3

- Restricted Signal History to administrators.
- Redirected unauthorized History views to Current Signal.
- Verified separate player and administrator interface permissions.

## v0.4.2

- Renamed the public mod to Cursed Frequencies.
- Changed the internal mod ID from LostFrequencies to CursedFrequencies.
- Replaced the Workshop thumbnail and in-game poster.
- Server owners must update their Mods entry to CursedFrequencies.

## v0.4.1

- Fixed Build 42 global alerts using an unsupported five-argument HaloTextHelper call.
- Corrected the sandbox-options schema header for the current Build 42 parser.
- Verified Reroll Random, Shorten -1 Day, global alerts, and server synchronization.

## v0.4.0

- Rebuilt the F8 interface as a 1080x700 command-center terminal.
- Added Current Signal, Curse Index, Signal History, and Admin Control tabs.
- Separated intensity, countdown, duration, rotation, and event ID into readable sections.
- Added a scrollable view of the persistent 20-entry curse history.
- Fixed administrator controls failing to appear when status arrived after the panel opened.
- Added live tab visibility and status refresh behavior.
- Corrected Build 42 local packaging and changed the manifest version key to `modversion`.
- Removed the conflicting root-level `mod.info`; Build 42 now uses `42/mod.info`.

## v0.3.0

- Added independent player exposure, kill, death, qualification, and survival records.
- Added cosmetic Signal Survivor, Severe Signal, Three Days in the Static, Frequency Resistant, and Static Proof badges.
- Added per-curse result summaries for Discord and website relays.
- Added read-only Survivor League client/server integration hooks without changing canonical scores.
- Added player-profile, event-statistics, and integration-health APIs.
- Added performance-safe tracking with no world, corpse, loot, vehicle, or zombie population scans.
- Added a five-percent chance of Clear Signal, Second Wind, or Quiet Frequency beneficial anomalies.

## v0.2.0

- Randomized curse duration from one to three real-world days.
- Added morning and evening broadcasts on every active day.
- Added final-evening expiration warnings.
- Added randomized Faint, Active, and Severe signal intensities.
- Added F8 player status and administrator control interface.
- Added login/respawn grace period and optional administrator exemption.
- Added persistent 20-entry curse history and three-curse repeat avoidance.
- Added pause, resume, reroll, select, extend, shorten, and manual reminder controls.
- Added client/server protocol handshake and mismatch warning.
- Added lifecycle callbacks for Radio, Survivor League, website, and relay integrations.
- Expanded structured relay records with duration and intensity.

## v0.1.0

- Added persistent real-world Daily Curse scheduling.
- Added separate activation and reminder transmissions.
- Added six reversible live-safe curses.
- Added optional Radio Frequencies v0.11.2 server API integration on 102.8 MHz.
- Added global player alerts and reconnect status notices.
- Added structured, idempotent Discord relay log records.
- Added admin-validated commands and a public server integration API.
- Added Build 42 native Sandbox Options and English translations.
