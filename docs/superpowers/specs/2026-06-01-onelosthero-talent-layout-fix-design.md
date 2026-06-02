# OneLostHero — Talent Layout & Polish Fix (design)

Date: 2026-06-01
Status: approved (Approach A), pending implementation

## Problem

OneLostHero (`BaseClass npc_dota_hero_kez`) has broken talents:

- Talents could not be selected except the lone built-in `special_bonus_attack_speed_15`.
- A prior fix attempt changed the talents' `AbilityType` to the `DOTA_`-prefixed form, which
  pushed all talents onto the **skill bar** as leveable abilities (see screenshot 2026-06-01).

Two independent root causes:

1. **Wrong AbilityType token.** Vanilla `npc_abilities.txt` uses the **short** form everywhere
   — `ABILITY_TYPE_ATTRIBUTES` (431×), `ABILITY_TYPE_ULTIMATE`, `ABILITY_TYPE_BASIC`,
   `ABILITY_TYPE_HIDDEN`. There is **no** `DOTA_`-prefixed `AbilityType` in the game. The engine
   treats the unrecognized `DOTA_ABILITY_TYPE_ATTRIBUTES` as a plain ability, so each talent
   rendered as a leveable skill-bar slot. (Corollary: the `vanishing_point.txt` comment claiming
   the ult *requires* the `DOTA_` prefix is incorrect; the ult is gated by occupying the ult slot.)

2. **Kez is a non-standard base layout.** Kez has 11 real abilities in `Ability1`–`Ability11`
   (incl. `kez_talon_toss`, `kez_shodo_sai`, `kez_switch_weapons`, `kez_ravens_veil`,
   `kez_shodo_sai_parry_cancel`) and its **talents live at `Ability12`–`Ability19`**, not 10–17.
   OneLostHero defines only `Ability1`–`7` + talents at `Ability10`–`17`, so it (a) **inherits
   Kez's `Ability8`/`Ability9`** as stray skill-bar abilities, and (b) places its talents in the
   wrong slots for a Kez-based hero, so the client (which lays out a custom hero from its
   `BaseClass`) does not render them in the talent tree. Flasaro works because Dragon Knight is a
   standard-layout base with talents at 10–17.

## How talents work (reference, from Kez's own files)

- A **unique** talent needs **no standalone ability definition**. It is just a name referenced in
  an `AbilityN` slot plus a **value-link** inside the ability it modifies:
  `"radius" { "value" "X" "special_bonus_unique_kez_raptor_dance_radius" "+50" }`.
- Talents are grouped into tiers by order within the talent slots: pair 1 → L10, pair 2 → L15,
  pair 3 → L20, pair 4 → L25. Absolute slot index does not change this as long as order is kept.
- OneLostHero already implements value-links correctly for 5 of its 7 unique talents. The other
  two (`charges`, `fear_pierce`) are **behavioral**, read in Lua via
  `FindAbilityByName(hero, "<talent>"):GetLevel()`, so those two **must exist as real abilities** —
  which is why OneLostHero keeps explicit `ability_lua` talent definitions (Kez's auto-generated
  talents would not satisfy a Lua `FindAbilityByName`).

## Chosen approach (A): mirror Kez's slot layout

Keep `BaseClass npc_dota_hero_kez` (so the Kez model + animations are guaranteed correct on the
native skeleton). Align OneLostHero's ability slots to Kez's structure: real abilities + hidden
fillers in `Ability1`–`11`, the 8 talents in `Ability12`–`19`. Revert the AbilityType to the short
form. Keep the explicit `ability_lua` talent definitions.

**Talent effects are unchanged.** Same 8 talent names, same value-links, same Lua reads, same
localization strings. Only the slot positions move and the AbilityType token reverts.

### New `npc_dota_hero_onelosthero` ability slots

| Slot | Value | Note |
|------|-------|------|
| Ability1 | `onelosthero_second_stroke` | Q (unchanged) |
| Ability2 | `onelosthero_blindspot_dagger` | W (unchanged) |
| Ability3 | `onelosthero_false_hero` | E (unchanged) |
| Ability4 | `generic_hidden` | (unchanged) |
| Ability5 | `generic_hidden` | (unchanged) |
| Ability6 | `onelosthero_vanishing_point` | R / ult (unchanged; matches Kez ult slot) |
| Ability7 | `onelosthero_lost_signal` | Innate (unchanged; `"Innate" "1"`) |
| Ability8 | `generic_hidden` | **new** — suppress inherited `kez_talon_toss` |
| Ability9 | `generic_hidden` | **new** — suppress inherited `kez_shodo_sai` |
| Ability10 | `generic_hidden` | **new** — override `kez_ravens_veil` |
| Ability11 | `generic_hidden` | **new** — override `kez_shodo_sai_parry_cancel` |
| Ability12 | `special_bonus_attack_speed_15` | L10 left (was Ability10) |
| Ability13 | `special_bonus_unique_onelosthero_invis` | L10 right (was Ability11) |
| Ability14 | `special_bonus_unique_onelosthero_second_stroke` | L15 left (was Ability12) |
| Ability15 | `special_bonus_unique_onelosthero_explosion` | L15 right (was Ability13) |
| Ability16 | `special_bonus_unique_onelosthero_charges` | L20 left (was Ability14) |
| Ability17 | `special_bonus_unique_onelosthero_silence` | L20 right (was Ability15) |
| Ability18 | `special_bonus_unique_onelosthero_fear_pierce` | L25 left (was Ability16) |
| Ability19 | `special_bonus_unique_onelosthero_break` | L25 right (was Ability17) |

### Other changes

- `onelosthero_talents.txt`: revert `AbilityType` on all 7 talents from `DOTA_ABILITY_TYPE_ATTRIBUTES`
  back to `ABILITY_TYPE_ATTRIBUTES` (short, vanilla-correct). Correct the header comment that wrongly
  claimed the full prefix is required.
- Manacost (already fixed, kept): `second_stroke` `GetManaCost` reads `GetSpecialValueFor("mana_cost")`
  (client-safe) instead of `GetAbilityKeyValues()`, so the HUD shows the cost. No change needed here.
- Model fixes (already done, kept): hero + Echo unit use `models/heroes/kez/kez_base.vmdl`;
  mr_bomber uses `models/heroes/gyro/gyro.vmdl`.

## Out of scope

- No change to talent numbers, descriptions, or localization (already present and correct).
- No change to ability behavior or values.
- mr_bomber is unrelated to the talent work and already fixed.

## Verification (requires in-client play-test by user)

1. Pick OneLostHero. Skill bar shows exactly: Q/W/E, R, innate — **no stray Kez abilities**.
2. At level 10/15/20/25 the **talent tree** opens (not skill-bar slots) and **every** talent can be
   selected on both sides.
3. Selecting value talents changes the linked values (e.g. +20% Second Stroke echo damage,
   +80 False Hero explosion); behavior talents apply (False Hero 2 charges; Vanishing Point fear
   pierces debuff immunity).
4. Second Stroke shows its mana cost (80/90/100/110) on the HUD.

### Fallback if talents still won't select after the layout fix

Move to the pure value-link model (Approach C): drop the explicit talent definitions and add
synthetic value-links for the two behavioral talents so they auto-generate like vanilla unique
talents. Recorded here so the next session has the path without re-deriving it.
