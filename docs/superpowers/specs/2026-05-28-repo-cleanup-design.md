# Repo Cleanup — Design

**Date:** 2026-05-28
**Project:** Dota 2 - Meme Mode
**Spec:** Cleanup (#1 of 3: this · #2 Flasaro custom hero · #3 UI overhaul)

## Context

`scripts/npc/` mixes engine-loaded files with large unwired reference material,
which makes the tree confusing. Three categories of cruft exist, none referenced
by any `#base` include (verified):

1. **Junk dir** `scripts/npc/_heroes/scripts/npc/heroes/npc_dota_hero_*.txt` —
   125 files written by a misfired generator run (nested output path bug).
2. **Legacy per-hero dumps** `scripts/npc/_heroes/npc_dota_hero_*.txt` — 125
   files; the regeneration source for the generator in `tools/`.
3. **Valve reference dumps** — 7 `__`-prefixed files (`__npc_abilities.txt`,
   `__npc_heroes.txt`, `__items.txt`, `__npc_units.txt`, `__neutral_items.txt`,
   `__herolist.txt`, `__npc_heroes_custom.txt`, ~150k lines total).

Also: `mgmod.code-workspace` is a leftover brand name.

The live per-hero ability system (`scripts/npc/heroes/<hero>/abilities.txt`, 124
folders, wired via `#base` in `npc_abilities_custom.txt`) is correct and stays.

## Goal

`scripts/npc/` contains only files the game loads. All unwired reference material
lives under `docs/reference/npc/`, clearly labeled. No leftover brand strings.

## Changes (locked)

| # | Action | Target |
|---|--------|--------|
| 1 | Delete | `scripts/npc/_heroes/scripts/` (nested junk, 125 files) |
| 2 | Move   | `scripts/npc/_heroes/npc_dota_hero_*.txt` → `docs/reference/npc/_heroes/` |
| 3 | Move   | `scripts/npc/__*.txt` (7 files) → `docs/reference/npc/` |
| 4 | Repoint | generator `SRC`, module docstring, `tools/README.md` → new `_heroes/` path |
| 5 | Add    | `docs/reference/npc/README.md` (explains: unwired reference, not loaded) |
| 6 | Rename | `mgmod.code-workspace` → `dota2_meme_mode.code-workspace` |

Use `git mv` so history is preserved.

## Not touched

- The 124 `heroes/<hero>/abilities.txt` folders (desired structure).
- Any `#base`-loaded file, Panorama panels, Lua vscripts.

## Verification

- `python -m pytest tools/ -q` → still 18 passed.
- `python tools/generate_hero_ability_files.py --dry-run` → "124 heroes with dumps".
- `grep` confirms no `#base` line references a moved/deleted file.
- `git status` shows moves as renames (history preserved).

## Out of scope

Flasaro custom hero (#2) and UI overhaul (#3) — separate specs.
