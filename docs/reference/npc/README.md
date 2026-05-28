# NPC reference dumps

**These files are reference only. The game does NOT load anything here.**

They live outside `game/.../scripts/npc/` on purpose, so that directory contains
only files the engine actually loads via `#base`.

## Contents

| Path | What it is |
|------|-----------|
| `_heroes/npc_dota_hero_*.txt` | Per-hero ability dumps. **Source** for the generator (`tools/generate_hero_ability_files.py`), which produces the live `scripts/npc/heroes/<hero>/abilities.txt` files. |
| `__npc_abilities.txt` | Full Valve ability definitions (reference for editing/cloning abilities). |
| `__npc_heroes.txt` | Full Valve hero definitions. |
| `__npc_heroes_custom.txt` | Custom-hero definition reference. |
| `__npc_units.txt` | Full Valve unit definitions. |
| `__items.txt` | Full Valve item definitions. |
| `__neutral_items.txt` | Neutral item tiers reference. |
| `__herolist.txt` | Hero list reference. |

## Usage

Grep these when you need a stock Valve definition to copy or tune. To regenerate
the per-hero override files after editing a dump (or after a Dota patch):

    python tools/generate_hero_ability_files.py
