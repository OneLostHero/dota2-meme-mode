# Flasaro Custom Hero — Design

**Date:** 2026-05-28
**Project:** Dota 2 - Meme Mode
**Spec:** #2 of 3 (cleanup done · this · #3 UI overhaul)

## Goal

Add a new, selectable custom hero **Flasaro** that uses the Dragon Knight model
and a kit of four borrowed base-game abilities, with Sven's talent tree as a
placeholder ("for the time being").

## Requirements (locked)

| Property | Value |
|----------|-------|
| Name | Flasaro |
| Model | Dragon Knight (`models/heroes/dragon_knight/dragon_knight.vmdl`) |
| Ability1 (Q) | `antimage_blink` (Anti-Mage Blink) |
| Ability2 (W) | `riki_blink_strike` (Riki Blink Strike) |
| Ability3 (E) | `sven_great_cleave` (Sven Great Cleave) |
| Ability6 (R) | `sven_gods_strength` (Sven ultimate) |
| Talents (Ability10–17) | Sven's 8 `special_bonus_*` talents (placeholder) |
| Access | Selectable in the normal hero-pick roster |

All four ability keys and the Sven talent keys are verified present in the Valve
reference dumps (`docs/reference/npc/`).

## Approach: clone Dragon Knight via `override_hero`

Define a brand-new hero key `npc_dota_hero_flasaro` in
`scripts/npc/npc_heroes_custom.txt` with `"override_hero" "npc_dota_hero_dragon_knight"`.
This is the standard Dota 2 custom-game new-hero pattern:

- The new hero **clones** Dragon Knight as its base, inheriting the DK model,
  animations, and base stats automatically — which satisfies the model
  requirement with no extra asset work.
- We then override the ability slots and assign a unique `HeroID`, `Enabled 1`,
  and `AttributePrimary` so it is a distinct, separately-selectable hero (DK
  remains pickable too).

### Hero definition (shape)

```
"DOTAHeroes"
{
    "npc_dota_hero_flasaro"
    {
        "override_hero"       "npc_dota_hero_dragon_knight"   // clone base (model+anims)
        "HeroID"              "<unused id>"                   // unique; see HeroID note
        "Enabled"             "1"                             // flows into the pick pool
        "AttributePrimary"    "DOTA_ATTRIBUTE_STRENGTH"       // matches Sven/DK feel

        "Ability1"            "antimage_blink"
        "Ability2"            "riki_blink_strike"
        "Ability3"            "sven_great_cleave"
        "Ability4"            "generic_hidden"
        "Ability5"            "generic_hidden"
        "Ability6"            "sven_gods_strength"

        "Ability10"           "special_bonus_unique_sven_5"
        "Ability11"           "special_bonus_attack_speed_15"
        "Ability12"           "special_bonus_unique_sven_3"
        "Ability13"           "special_bonus_unique_sven_8"
        "Ability14"           "special_bonus_unique_sven_6"
        "Ability15"           "special_bonus_unique_sven_7"
        "Ability16"           "special_bonus_unique_sven_2"
        "Ability17"           "special_bonus_unique_sven_4"
    }
}
```

Exact inherited stat keys (Model is inherited; copy explicitly only if the clone
does not pick it up in testing) are finalized during implementation.

### HeroID

New heroes need a unique `HeroID` not used by any stock hero. Implementation
picks a high unused integer (e.g. in the 1000+ range, after scanning
`docs/reference/npc/__npc_heroes.txt` for the current max) to avoid collision
with current and near-future Valve heroes.

## Roster wiring

The runtime hero pool is built in `legends_of_dota/plugin.lua → LoadHeroes()`,
which reads `scripts/npc/npc_heroes.txt` (base game; `#base`-includes
`npc_heroes_custom.txt`) and pools every hero with `Enabled 1`. A correctly
defined Flasaro therefore appears in the pool automatically.

Planning must **verify** two assumptions in-game:
1. `LoadKeyValues('scripts/npc/npc_heroes.txt')` resolves the `#base
   npc_heroes_custom.txt` include so Flasaro is present in the returned table.
2. The Panorama selection grid (`hero_selection.js`) renders a hero whose model
   is a cloned DK without a missing portrait/icon. If the portrait is missing,
   add a minimal hero-portrait/icon override (deferred detail).

## Localization

Add to `game/.../resource/addon_english.txt`:
- `"npc_dota_hero_flasaro"` → `Flasaro`
- `"DOTA_Tooltip_Ability_..."` — abilities keep their source tooltips (borrowed),
  so no new ability strings are strictly required; a short hero bio/lore line is
  optional and may be added.

## Files touched

| File | Change |
|------|--------|
| `scripts/npc/npc_heroes_custom.txt` | Add the `npc_dota_hero_flasaro` block |
| `resource/addon_english.txt` | Add Flasaro display name (+ optional lore) |
| `legends_of_dota/plugin.lua` | **Only if** verification shows the pool misses custom heroes — add a merge of `npc_heroes_custom.txt`. Avoided otherwise. |

No new ability KV files are needed: the four abilities are stock and already
loadable (Anti-Mage, Riki, Sven are all in the game).

## Risks

- **`override_hero` clone of a *playable* base (DK):** generally supported for
  cloning, but some patches make a new key that clones an active hero behave
  oddly (shared portraits, hero-grid placement). Mitigation: in-game test; if it
  conflicts, fall back to cloning a non-pooled hero or explicitly set Model +
  portrait keys on Flasaro.
- **Borrowed abilities on a non-native hero:** abilities like `riki_blink_strike`
  may reference Riki-specific modifiers/particles; they should function but
  particle/voice edge cases are possible. Test each of the four.
- **Talents:** Sven's `special_bonus_*` reference Sven abilities; some talents
  (e.g. cleave/warcry bonuses) will be inert because Flasaro lacks those exact
  abilities. Accepted — "Sven tree for the time being." Note inert talents.
- **Cannot be fully verified without launching the client.** The plan includes a
  manual in-game checklist; the user runs it.

## In-game verification checklist (manual, user-run)

1. Game loads with no KV parse errors in `console.log`.
2. Flasaro appears in the hero-selection grid and is pickable.
3. On pick, Flasaro spawns with the Dragon Knight model.
4. Q/W/E/R are `antimage_blink` / `riki_blink_strike` / `sven_great_cleave` /
   `sven_gods_strength`, each castable and functional.
5. Talent tree shows Sven's talents; selecting levels works (inert ones noted).
6. Dragon Knight, Sven, Anti-Mage, Riki are all still independently selectable.

## Out of scope

- Custom model / original art for Flasaro (uses DK model by design).
- Bespoke ability rework or rebalancing (borrowed as-is).
- Replacing the placeholder Sven talent tree with a bespoke one (later).
- UI overhaul (#3).
