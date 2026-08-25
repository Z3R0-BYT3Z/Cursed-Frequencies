# Cursed Frequencies relay integration

The mod never stores a Discord token and never performs an outbound HTTP request. The existing VPS bridge remains the security boundary.

Match only lines that start with `[LostFrequencies]` and split fields on ` | `. Deduplicate outgoing Discord messages by `event_id` plus `event`. Persist delivered identifiers so a relay restart cannot repost an old activation.

Suggested Discord rendering:

```text
📻 CURSED FREQUENCIES — DAILY CURSE
RED STATIC
The transmission keeps survivors uneasy and alert.
Active: <t:START:F> until <t:END:F>
Frequency: 102.8 MHz
```

Only the relay should hold the Discord webhook or bot credential. Do not place credentials in Lua, `mod.info`, SandboxVars, Workshop files, or server logs.
## v0.5.1 delivery behavior

When Radio Frequencies is available, curse transmissions are stored in its
station history and delivered through its global chat/Discord announcement
path. The native Cursed Frequencies alert is used only as a fallback, avoiding
duplicate messages. Overhead text is disabled by default.
