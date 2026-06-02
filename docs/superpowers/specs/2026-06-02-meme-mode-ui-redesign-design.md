# Meme Mode UI Redesign — Design

**Date:** 2026-06-02
**Status:** Draft for review
**Scope:** A single coherent UI redesign across the custom game's setup screen and in-game HUD, implemented in phases. One visual language; three sub-projects.

---

## Background & goals

Meme Mode's UI has grown organically and now has real clarity problems the player surfaced directly:

- The **in-game upgrade list** (the "Boosted" system) stacks down the left edge as raw icons + bare percentages, shows no ability names, can hit ~199 entries, and **cannot be hidden** — it eats the screen.
- The **red currency** is unlabeled: players can't tell what it is, how much they have, or what the conversion popup (`50/500/5000/50000`) does.
- The **setup screen** has a mysterious unlabeled `0–10` column (these are save-slot presets) and a long flat plugin list (~30 entries) that's hard to sort.

**Goal:** make the UI legible and on-brand. Establish one visual language ("Refined Chaos"), then apply it to fix the three areas above. Clarity first; keep the meme personality in the accents, not in the noise.

**Non-goals / parked (tracked elsewhere):**
- **Loading-screen double-stall (#1)** — separate debugging task; strong unconfirmed hypothesis (the `custom_hero_portrait.js` in-game tree-walk burst). Not part of this redesign.
- **Cross-session settings persistence (#3)** — needs an external HTTP backend (Valve's account-record API is Preview/Unreleased). Parked. *Note: its surface is the setup screen's preset slots redesigned here, so this redesign should leave a clean seam for it.*

---

## Visual language: "Refined Chaos"

The unifying direction (chosen over "Full Meme" and "Clean & Pro"). Clean, readable panels and clear hierarchy carry the function; meme personality lives in accent color, iconography, and playful copy.

- **Surfaces:** dark panels (`#15171c` body, `#1b1e26` headers), 1px borders (`#2a2f3a`), 8px radius, subtle header gradient.
- **Text:** `#e8ebf0` primary, `#7a8190` secondary, small uppercase section labels with letter-spacing.
- **Accents:** lime (`#c8ff5e`) for primary/positive headers and enabled state; red/magenta (`#ff5e8a` / `#ff6b6b`) for the currency and negative deltas; green (`#7CFC00`) for positive deltas.
- **Personality:** expressed through icons (⚡, ◆), the meme currency name, and copy — never through reduced legibility.
- These tokens become shared CSS so all three sub-projects match. (Audit the existing scattered `cyber*.css` / `cyberpunk-2077.css` themes and converge on this token set rather than adding another.)

---

## Sub-project 2C — In-game upgrade drawer (highest priority)

Replaces the unbounded left-edge upgrade stack.

**Placement & behavior (chosen: left collapsible drawer):**
- A slim tab docked on the **left edge** (where upgrades already live, preserving muscle memory).
- Click to **slide out** the full panel; click the collapse handle (◀) to retract it to just a count badge + Boost Juice balance.
- Collapsed by default once overlays/data are placed, so it reclaims the screen.

**Panel contents:**
- **Header:** `⚡ ABILITY UPGRADES` + total count + `▾` collapse, and a balance row showing Boost Juice (`◆ N`) plus a `⇄ Convert gold` button (see 2B).
- **Rows:** `icon · ability name · affected stat · ±%`. Positive deltas green, negative red. This replaces bare-percentage rows — every entry names the ability and the stat it modifies.
- **Search** box filtering by ability/stat name.
- **Scroll** for the full set (must handle ~199 entries smoothly — virtualize or cap rendered rows if needed for performance).

**Notes / to confirm during implementation:**
- The drawer is primarily a **display** of owned/accumulated upgrades. Buying new upgrades currently flows through the currency spend-options; whether to fold "buy" into the drawer is a possible extension, not required for v1.
- Source files: in-game upgrade display layout/script/style (the `boosted` / `upgrade*` / `stonks` Panorama set) and `custom_hero_portrait.js`'s neighbor HUD region. Confirm exact panels when implementing.

---

## Sub-project 2B — Currency clarity ("Boost Juice")

The red currency = points spent on ability upgrades, earned by converting gold at a flat **50 gold : 1 point** rate (the old `50/500/5000/50000` popup was just bulk amounts of that one rate).

- **Name:** **Boost Juice**. Internally still the configurable currency (system supports multiple), displayed with a clear name + tooltip ("Spend on ability upgrades").
- **Identity:** keep the **red ◆**, refined to the Refined-Chaos accents.
- **Balance:** shown in the upgrade drawer header (single source of truth). The **standalone red chip by the shop is removed** — its role moves into the drawer.
- **Converter** (opens from the drawer header `⇄ Convert gold`):
  - States the rate plainly: "50 gold = 1 point".
  - Shows current **Gold** and **Boost Juice** balances.
  - Bulk-convert buttons each labeled with exact cost → gain (`−50 gold → +1 ◆`, `−500 → +10`, `−5,000 → +100`, `−50,000 → +1,000`).
  - Options the player can't afford are **dimmed with a reason**.
- Source files: `currencies.js` / `currencies.xml` / `currencies.css` (the `CurrencyBox` / `ShowOptionMenu` / earn-options flow), localization strings.

---

## Sub-project 2A — Setup screen

Two fixes under the same visual language.

**Presets (the mystery `0–10`):**
- Relabel the bare `0–10` slot column as **named presets** with explicit **Save / Load**.
- Each slot shows a name (or "empty"); host can name a saved setup.
- Surface copy notes that presets currently **reset each session** (cross-session memory = parked #3). Keep the data seam clean so #3 can later persist these without UI rework.
- Source: `plugin_settings.*` Panorama set + `PluginSystem` save-slot net table (`save_slots`, `current_save_slot`, `GenerateSave`/`LoadSettingsString` already exist).

**Plugin list (chosen: collapsible categories):**
- **Search** box filtering across all modes.
- **Collapsible category groups**, each with an enabled-count: **Core / Heroes & Abilities / Chaos & Fun / Sandbox & Dev / Seasonal**. (Exact bucket membership to be confirmed; initial proposal in the brainstorm notes.)
- **Enabled** modes clearly marked (green ● / glow); changed-from-default already tracked via `has_changed`.

**Related cleanup (in scope — it directly degrades this screen):**
- Fix the missing **`panorama/localization/addon_english.txt`** load (engine warns `ILocalize::AddFile() failed`), which is why setup shows `#Plugin_..._Description` raw strings instead of real descriptions. Settings strings live in `resource/addon_english.txt`; ensure a Panorama-localization copy/path exists so descriptions render.

---

## Suggested implementation phasing

1. **Visual-language tokens** — shared CSS variables/classes for Refined Chaos; converge existing themes onto them.
2. **2C upgrade drawer** — biggest player-facing win; establishes the panel pattern.
3. **2B currency** — small, plugs into the drawer header; remove the standalone chip.
4. **2A setup screen** — presets relabel + categorized searchable list + localization fix.

Each phase is independently shippable and testable in-client.

---

## Risks & open questions

- **199-row performance:** the drawer must render large upgrade counts without HUD hitching — likely needs row virtualization or a render cap. (Especially relevant given the parked #1 stutter hypothesis lives in the same HUD region.)
- **Exact upgrade-display source panels** and whether "buy" should live in the drawer — confirm by tracing the `boosted`/`upgrade`/`stonks` Panorama wiring during implementation.
- **Category bucket membership** for ~30 plugins — needs a quick pass to assign each plugin to a bucket; surface for host confirmation.
- **Localization path** for Panorama vs `resource/` — confirm the correct location Dota expects for custom-game Panorama strings.
