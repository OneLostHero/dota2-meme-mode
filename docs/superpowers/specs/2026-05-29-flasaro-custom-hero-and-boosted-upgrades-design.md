# Flasaro Custom-Hero Framework + Boosted Upgrade Fix — Design

Date: 2026-05-29
Status: Approved (sections A and B), pending written-spec review

## Problem

Three defects, grouped into two efforts:

1. **Flasaro does not spawn.** He is selectable (correct stats, kit) and the match
   reaches `GAME_IN_PROGRESS`, but no hero entity is created for the player — empty
   ability bar, no control. A valid unused HeroID (24 is a real gap), precache, and
   a facet did not fix it.
2. **Flasaro's pick-screen portrait is blank** (the large 3D render is black).
3. **Boosted red-currency upgrades leak onto the skill bar and can consume skill
   points.** In the original MGMod these upgrades appear only in the left-side
   upgrade panel and cost red currency — never skill points, never the skill bar.

### Reference oracle

The user supplied a working custom-hero definition (`npc_dota_hero_aqua`) and the
original mod repo (`https://github.com/drteaspoon420/MGMod`). The key differences
vs. our Flasaro: the working hero declares **`BaseClass`** (a real vanilla hero)
and uses a **high, unused `HeroID`** (203), plus a full set of unit fields. It has
**no `Facets` block** — consistent with the user's statement that **facets have
been removed from the game**.

## Part A — Custom-hero framework (fixes spawn + portrait)

**Root cause:** Flasaro has no `BaseClass`. Without a base hero class the engine
has no entity class to instantiate (no spawn) and the client has nothing to render
(black portrait). This is the single change the working `aqua` example has that we
lack.

**Changes** (all in `game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt`):

- Add `"BaseClass" "npc_dota_hero_dragon_knight"`. BaseClass *inherits* a class; it
  does not override, so Dragon Knight remains a separate, fully playable hero.
- Change `"HeroID"` from the recycled gap `24` to a high, clearly-unused value
  (`250`; well under the engine max, no collision with any real hero). Everything
  else keys off the hero *name* (`npc_dota_hero_flasaro`) — herolist, portrait
  images, localization, the spawn fallback — so only this KV value changes.
- Add the unit fields the working template has and ours lacks: `CombatClassAttack`,
  `CombatClassDefend`, `UnitRelationshipClass`, `BoundsHullName`,
  `MovementCapabilities`, `AttackDamageType`, `TeamName`.
- **Remove the `Facets` block** (facets removed from the game; the working example
  has none).
- **Add Flasaro's innate = Sven's innate passive.** Resolve the exact ability key
  from Sven's current hero definition during implementation and wire it as
  Flasaro's innate (per current Dota innate conventions).
- Keep his existing kit: AM blink (Q), Riki blink strike (W), Sven cleave (E),
  Sven God's Strength (R), Sven talent tree.

**Supporting pieces (unchanged / retained):**

- Keep the precache loop in `addon_game_mode.lua` (`PrecacheUnitByNameSync` over
  `npc_heroes_custom.txt`).
- Keep Flasaro in `herolist.txt` so he is selectable.
- Keep the `custom_heroes` plugin's `CreateHeroForPlayer` fallback as a guarded
  safety net; with `BaseClass` the normal spawn pipeline should make it a no-op.

**Success criteria:** picking Flasaro (Custom Heroes toggle on) yields a
controllable hero with a working ability bar and his innate, the pick-screen
portrait renders the DK model, and Dragon Knight remains independently playable.

## Part B — Boosted upgrades confined to the left panel + red currency

Implemented after Part A is verified. Diagnosis-first, because the exact mechanism
is not yet known and the boosted system is intricate.

**Desired end state:** the red-currency boosted upgrades appear only in the
left-side upgrade panel, are purchased with red currency, and are never registered
as castable/levelable hero abilities (so they cannot appear on the skill bar or
consume skill points). The normal talent tree (10/15/20/25, talent points) keeps
working untouched.

**Step 1 — Diagnose.** Determine what is actually on the bar — boosted *upgrade
pseudo-abilities* vs. real `special_bonus` talents placed in visible slots — and
find exactly where a skill/talent point is consumed. Compare our `boosted/plugin.lua`,
`upgrade.xml`/`upgrade.js`, `inspect_upgrades.*`, the per-hero
`heroes/<name>/abilities.txt` `#base` structure, and `npc_abilities_custom.txt`
against the original `drteaspoon420/MGMod` to isolate what diverged in this fork.
(Note: git shows the per-hero `#base` structure came in with the original import,
so it is likely original behavior, not a regression — to be confirmed by the diff.)

**Step 2 — Fix at the source.** Apply the smallest change that confines boosted
upgrades to the left panel + red currency. This may be a boosted *config/setting*
(e.g. `only_slot`, a list, a currency flag) or a code/UI fix — the diagnosis
decides. No blind edits to the boosted system.

**Success criteria:** in-game, red-currency upgrades show only in the left panel,
cost red currency, never appear on the skill bar, and never consume skill/talent
points; the normal talent tree still functions.

## Out of scope

- Bespoke custom abilities for Flasaro (he keeps the borrowed vanilla abilities).
- Generalizing the custom-hero framework to additional new heroes (the pattern
  will generalize, but only Flasaro is in scope now).
- Pre-game setup polish / settings persistence (tracked separately).

## Testing

Each iteration is verified by the user in-game (the agent cannot run the client):

- Flasaro: spawns, controllable, ability bar populated, innate present, portrait
  renders. Dragon Knight still playable. Largo/Ringmaster/Kez still pickable.
- Boosted: upgrades only in the left panel, cost red currency, absent from the
  skill bar, consume no skill/talent points; normal talents still work.

## Risks / constraints

- The agent cannot launch the client; every change is validated by a user
  play-test, so changes are batched conservatively and one concern at a time.
- Part B's fix location (config vs. code vs. UI) is unknown until diagnosis; the
  spec commits to the *outcome*, not a specific file.
