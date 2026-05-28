# Dota 2 - Meme Mode tools

## generate_hero_ability_files.py

Generates `scripts/npc/heroes/<hero>/abilities.txt` (annotated full ability
overrides) for every active hero, and rewrites the `#base` include block in
`npc_abilities_custom.txt`.

Run from the repo root:

    python tools/generate_hero_ability_files.py            # generate
    python tools/generate_hero_ability_files.py --dry-run  # report only

- **Source:** `docs/reference/npc/_heroes/npc_dota_hero_<x>.txt` dumps (never modified).
- **Output:** `scripts/npc/heroes/<x>/abilities.txt` (overwritten on each run).
- **Idempotent:** safe to re-run after a Dota patch. Re-running overwrites the
  generated files, so re-apply any hand edits afterward (use `git diff`).

Annotations injected:
- `// ---- <Name>  (<key>) ----` header above each ability.
- `// higher = stronger` / `// lower = stronger` / `// check tooltip` on values.

Run the unit tests with: `python -m pytest tools/ -q`
