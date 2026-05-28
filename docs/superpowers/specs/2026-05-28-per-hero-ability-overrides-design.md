# Per-Hero Ability Override System — Design

**Date:** 2026-05-28
**Project:** MGMod → "Dota 2 Meme Mode" remake
**Spec:** #1 of 3 (this) · #2 Map terrain refresh · #3 UI overhaul

## Context

MGMod is a Dota 2 custom-game sandbox built around a toggleable plugin system. The
original mod forbade base-game KV overrides ("fork it instead"). This project **is**
that fork — a remake branded "Dota 2 Meme Mode" — so overriding base-game hero
abilities is now allowed and is the point.

Today the custom abilities in the repo are organized **by author**
(`scripts/vscripts/abilities/<author>/<ability>/`) and are generic sandbox abilities
(multicast, blink, BKB, etc.), not hero abilities. The actual per-hero ability data
exists only as **unwired reference dumps** in `scripts/npc/_heroes/npc_dota_hero_*.txt`
(126 full Valve ability definitions). They are not included via any `#base` chain, so
editing them does nothing in-game.

Ability/hero KVs load through `scripts/npc/npc_abilities_custom.txt` (auto-loaded by
the engine), which pulls feature/author files in via `#base` lines.

## Goal

Give every active hero (~120, per `scripts/npc/_activelist.txt`) a dedicated folder
where a maintainer can **hand-edit ability values** and have the change take effect
in-game. Files must be **self-documenting** so editing is approachable.

Out of scope for this spec: map terrain refresh (#2), UI overhaul (#3), genuine
ability reworks / value-key renames (structure must merely not preclude them).

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Edit method | Hand-edit per-hero KV files |
| Hero scope | All active heroes in `_activelist.txt` (~120) |
| Structure | Folder per hero: `scripts/npc/heroes/<hero>/abilities.txt` |
| Override style | Full ability copy per ability (total control, self-documenting) |
| Edit type | Mostly numeric tuning; renames possible but not the focus |
| Content source | Re-extract from live install; **fall back to existing `_heroes/` dumps if extraction is blocked** |
| Build tool | Python script in new top-level `tools/` |

## Structure

```
scripts/npc/heroes/
  riki/
    abilities.txt      # full ability defs, annotated — the file you edit
    notes.md           # optional, per-hero rework notes (not loaded by game)
  queenofpain/
    abilities.txt
  skeleton_king/       # Wraith King
    abilities.txt
  ... ~120 hero folders
```

The legacy `scripts/npc/_heroes/` folder is **retired** once migration is verified
working in-game, then deleted.

## Load wiring

`scripts/npc/npc_abilities_custom.txt` gains one line per hero:

```
#base "heroes/riki/abilities.txt"
#base "heroes/queenofpain/abilities.txt"
...
```

Placement rules:
- The per-hero block is inserted **after** `#base "npc_abilities_fix.txt"` so hero
  overrides take precedence over the builtin-enabling fixes.
- Each hero file is a **full** definition of that hero's abilities, so it overrides
  Valve's builtin definition for those ability keys.
- Author/feature files (drteaspoon, acs, abrahamblinkin, tremulous, halloween) use
  distinct custom ability keys, so key collisions with hero overrides are not
  expected. The plan verifies this (collision scan) before shipping.

## Content source

Priority order:
1. **Re-extract from the live install** —
   `R:\SteamLibrary\steamapps\common\dota 2 beta\game\dota\pak01_dir.vpk`, path
   `scripts/npc/...`, via Valve's Source 2 Viewer CLI or the SDK `vpk` tool. Guarantees
   current values. The plan **verifies the install's actual file layout first** rather
   than assuming.
2. **Fallback (chosen if extraction is blocked):** migrate the existing
   `scripts/npc/_heroes/npc_dota_hero_*.txt` dumps already present in the repo. Ship
   now, refresh values later. The resulting folder structure is identical either way.

## Self-documenting format

Each `abilities.txt` is produced by the generator with annotations, then hand-edited.
Example:

```
"DOTAAbilities"
{
    //============================================================
    //  Smoke Screen  (riki_smoke_screen)
    //  Icon: riki_smoke_screen
    //============================================================
    "riki_smoke_screen"
    {
        "AbilityTextureName"   "riki_smoke_screen"   // keeps correct icon
        // ... full ability definition ...
        "AbilityValues"
        {
            "radius"          "325"   // higher = stronger (larger cloud)
            "duration"        "6.0"   // higher = stronger
            "miss_rate"       "60"    // higher = stronger (more misses)
            "AbilityCooldown" "13"    // lower = stronger
        }
    }
}
```

This resolves the three editing pain points:
- **Name header** → ability's display name is visible in the file.
- **`AbilityTextureName` preserved** → correct icon in the data layer.
- **Inline direction hints** → "increase or decrease?" answered per value.

### Direction-hint heuristic

The generator labels each value using name-pattern rules:
- `cooldown`, `manacost`, `cast_point`, `*_reduction` (cost-like) → **lower = stronger**
- `damage`, `duration`, `radius`, `range`, `*_pct`, `heal`, `bonus_*`, `count`,
  `slow`, `miss_rate` → **higher = stronger**
- Unmatched keys → no directional claim; comment reads `// effect unclear — see tooltip`.

Heuristic output is a best-effort aid, explicitly hand-correctable. Where a localized
description exists in `resource/_abilities_english.txt`, the value's friendly label is
appended to the comment.

**Persona/skin icon edge case:** some heroes' personas use alternate ability icons.
This spec only guarantees the base `AbilityTextureName` is present and correct in the
data; making persona-specific icons display nicely is deferred to the UI spec (#3).

## Build process (one-time generator)

A Python script in `tools/` (e.g. `tools/generate_hero_ability_files.py`). It is a
**build/migration tool, not the editing interface** — after it runs, you edit the
generated files by hand. Steps:

1. Resolve the source ability KVs (live extraction, else `_heroes/` dumps).
2. For each active hero in `_activelist.txt`, collect that hero's ability blocks.
3. Read display names from `resource/_abilities_english.txt` for the name headers.
4. Apply the direction-hint heuristic to each `AbilityValues` entry.
5. Write `scripts/npc/heroes/<hero>/abilities.txt` (full defs + annotations).
6. Rewrite the per-hero `#base` block in `npc_abilities_custom.txt` (idempotent —
   safe to re-run after a future Dota patch).

Re-running the script after a Dota patch regenerates current values; hand edits are
expected to be re-applied on top (the plan will note this trade-off of the full-copy
approach and may emit a diff to ease re-application).

## Testing & verification

- **KV validity:** game loads with no KV parse errors in `console.log`.
- **Override takes effect:** for Riki, Queen of Pain, Wraith King — change one obvious
  value (e.g. an ability `AbilityCooldown` → 1), launch, confirm in-game.
- **No regressions:** author abilities (multicast, blink) and existing plugins still
  load and function.
- **Display:** test heroes show correct ability icons and names in-game.
- **Collision scan:** confirm no hero ability key is also defined by an author/feature
  `#base` file.

## Risks

- **Extraction tooling** may not be available/working on the box → mitigated by the
  `_heroes/` dump fallback.
- **Full-copy staleness:** copies freeze at extraction time; future Valve balance
  changes require re-running the generator. Accepted trade-off for total control and
  self-documentation.
- **Load-order / override correctness** for builtin abilities → verified by the
  in-game override test on the three sample heroes before mass rollout.

## Follow-on specs (not designed here)

- **#2 Map terrain refresh:** Dota ships maps only as compiled `.vpk`; editable Hammer
  `.vmap` sources are not in the install, so "refresh from current Dota" requires
  decompiling (lossy) or manual rebuild. Needs its own brainstorm.
- **#3 UI overhaul:** "better UI" — scope undefined; will need visual brainstorming.
  Inherits the persona-icon display concern from this spec.
