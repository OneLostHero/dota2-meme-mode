"""Generate per-hero ability override files for MGMod ("Dota 2 Meme Mode").

Reads the per-hero dumps in scripts/npc/_heroes/, writes annotated copies to
scripts/npc/heroes/<hero>/abilities.txt, and (re)writes the #base include block
in npc_abilities_custom.txt. Re-runnable. Source dumps are never modified.

Usage:
    python tools/generate_hero_ability_files.py [--dry-run]
"""
import sys
from pathlib import Path

# Allow running as a script (python tools/generate_hero_ability_files.py)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.hero_ability_gen import (  # noqa: E402
    annotate_file_lines, hero_short, parse_active_heroes,
    parse_localized_names, render_base_block, update_load_file,
)

REPO = Path(__file__).resolve().parents[1]
NPC = REPO / "game/dota_addons/mgmod/scripts/npc"
SRC = NPC / "_heroes"
OUT = NPC / "heroes"
LOAD_FILE = NPC / "npc_abilities_custom.txt"
LOC_FILE = REPO / "game/dota_addons/mgmod/resource/_abilities_english.txt"


def main(argv):
    dry_run = "--dry-run" in argv

    active = parse_active_heroes((NPC / "_activelist.txt").read_text(encoding="utf-8"))
    names = parse_localized_names(LOC_FILE.read_text(encoding="utf-8", errors="replace"))

    present = [h for h in active if (SRC / f"{h}.txt").exists()]
    missing = [h for h in active if not (SRC / f"{h}.txt").exists()]
    for h in missing:
        print(f"WARN: no dump for {h}; skipping")

    print(f"{len(present)} heroes with dumps (of {len(active)} active)")

    if dry_run:
        return 0

    for h in present:
        src_lines = (SRC / f"{h}.txt").read_text(
            encoding="utf-8", errors="replace"
        ).splitlines(keepends=True)
        annotated = annotate_file_lines(src_lines, names)
        dest = OUT / hero_short(h) / "abilities.txt"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text("".join(annotated), encoding="utf-8")

    block = render_base_block(present)
    LOAD_FILE.write_text(
        update_load_file(LOAD_FILE.read_text(encoding="utf-8"), block),
        encoding="utf-8",
    )
    print(f"wrote {len(present)} hero files and updated {LOAD_FILE.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
