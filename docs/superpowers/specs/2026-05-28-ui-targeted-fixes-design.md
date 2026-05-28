# UI Targeted Fixes (Pass A) — Design

**Date:** 2026-05-28
**Project:** Dota 2 - Meme Mode
**Spec:** #3 of 3 (cleanup done · Flasaro done · this)

## Goal

A low-risk first pass at the two UI surfaces flagged as confusing — the **pre-game
setup screen** and the **in-game HUD tool buttons** — without restructuring
layouts. Each fix is concrete, verifiable by reading code, and independently
shippable.

Prioritized by the user: (1) **clarify the unlock gate**, (2) **label HUD tool
buttons**. Plus one near-zero-risk bonus: (3) kill the lorem-ipsum placeholder.

## Fix 1 — Clarify the settings "unlock" gate (priority)

**Current behavior:** When a map preset / "forced mode" locks the sandbox
settings (`forced_mode.lock_level >= 1`), `plugin_settings` shows
`PluginUnlockScreen`: a single button labeled "Vote to unlock options" plus a
bare progress bar. There is no explanation of *why* settings are locked, what
unlocking does, or how many votes are needed / cast. `unlock_remote()` already
computes `c` (votes cast) and `d` (valid players) against
`forced_mode.vote_treshold`.

**Changes:**
- `plugin_settings.xml` — inside `PluginUnlockScreen`, add:
  - an explanatory `Label` (e.g. *"This mode locks the sandbox settings. Players
    can vote to unlock and change them."*), and
  - a live vote-tally `Label` (e.g. *"Votes: 2 / 4 needed"*) above/near the bar.
- `plugin_settings.js` — in `unlock_remote()`, populate the tally label from the
  already-computed `c`, `d`, and threshold (needed = `ceil(d * treshold/100)`).
- `addon_english.txt` — improve `PluginListUnlockButtonText` and add the new
  explanatory/tally string tokens.

**Out of scope:** changing the voting mechanic itself (threshold, who can vote).

## Fix 2 — Correct/Add HUD tool-button tooltips (priority)

**Audit result** (every `ButtonBar_*` toggle button):

| Tool | Current tooltip | Action |
|------|-----------------|--------|
| hero_builder | "Add Abilities" | keep |
| item_spawner | "Add Items" | keep |
| unit_spawner | "Add Units" | keep |
| modifier_spawner | "Add Modifiers" | keep |
| stonks | "Stonks" | keep |
| **soul_collector** | "Add Units" (wrong — copy-paste) | → **"Soul Collector"** |
| **hackerman** | "Add Units" (wrong — copy-paste) | → **"Hackerman"** |
| **inspect_upgrades** (`UpgradeInspectButton`) | none | → add **"Inspect Upgrades"** |

**Changes:**
- `soul_collector.js` — fix the bar-button `DOTAShowTextTooltip` text.
- `hackerman.js` — fix the bar-button `DOTAShowTextTooltip` text.
- `inspect_upgrades.js` — add `onmouseover`/`onmouseout` tooltip handlers to
  `UpgradeInspectButton` (mirroring the established pattern in the other tools).

Pattern is uniform across tools, so each change is a few lines and matches
existing style.

## Fix 3 — Kill the lorem-ipsum placeholder (bonus, low risk)

**Current:** `plugin_settings.xml` snippet `PluginSettings` hard-codes a "Zombie
ipsum…" lorem block as `PluginSettingsDescriptionText`'s default text; it shows
before a plugin is selected and for any plugin lacking a description.

**Change:** replace the lorem text with a neutral empty-state (e.g. *"Select a
plugin or mutator to see its description."*). Verify in `plugin_settings.js` that
a plugin with no description falls back to this neutral text rather than re-showing
lorem.

## Files touched

| File | Fix |
|------|-----|
| `panorama/layout/custom_game/plugin_settings.xml` | 1, 3 |
| `panorama/scripts/custom_game/plugin_settings.js` | 1, 3 |
| `panorama/scripts/custom_game/soul_collector.js` | 2 |
| `panorama/scripts/custom_game/hackerman.js` | 2 |
| `panorama/scripts/custom_game/inspect_upgrades.js` | 2 |
| `resource/addon_english.txt` | 1 (new/updated strings) |

## Risks

- Panorama is compiled/run only in the Dota client — these edits are verifiable by
  reading (string/tooltip/label changes, no logic rework), but final confirmation
  is in-game.
- `unlock_remote()` runs on a net-table update; the tally label must handle the
  pre-vote state (0 votes) without erroring.

## In-game verification checklist (manual, user-run)

1. Load a map preset that locks settings → unlock screen shows the explanation and
   a "Votes: X / Y" tally that updates as players vote.
2. Hover each HUD tool button → tooltip names match the tool (Soul Collector,
   Hackerman, Inspect Upgrades correct).
3. Open pre-game settings with no plugin selected → neutral empty-state text, no
   lorem ipsum.

## Out of scope (future passes)

- Plugin search/filter, list categorization (Approach B).
- Window-styling normalization, theme pass (Approach C).
- Restructuring the HUD into a grouped tray.
