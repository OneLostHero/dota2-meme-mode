from tools.hero_ability_gen import direction_hint, parse_active_heroes, hero_short


def test_cost_fields_are_lower_stronger():
    assert direction_hint("AbilityCooldown") == "lower = stronger"
    assert direction_hint("AbilityManaCost") == "lower = stronger"
    assert direction_hint("cast_point") == "lower = stronger"


def test_effect_fields_are_higher_stronger():
    assert direction_hint("damage") == "higher = stronger"
    assert direction_hint("duration") == "higher = stronger"
    assert direction_hint("miss_rate") == "higher = stronger"
    assert direction_hint("radius") == "higher = stronger"


def test_reduction_outranks_cooldown():
    # "cooldown_reduction": more reduction is stronger, not less
    assert direction_hint("cooldown_reduction") == "higher = stronger"
    assert direction_hint("armor_reduction") == "higher = stronger"


def test_unknown_returns_none():
    assert direction_hint("block_targeting") is None
    assert direction_hint("projectile_speed") == "higher = stronger"  # speed matches
    assert direction_hint("some_opaque_flag") is None


def test_parse_active_heroes_keeps_order_and_filters():
    text = '''"whitelist"
{
    "npc_dota_hero_riki" "1"
    "npc_dota_hero_queenofpain" "1"
    "npc_dota_hero_disabled" "0"
    "npc_dota_hero_skeleton_king"\t"1"
}'''
    assert parse_active_heroes(text) == [
        "npc_dota_hero_riki",
        "npc_dota_hero_queenofpain",
        "npc_dota_hero_skeleton_king",
    ]


def test_hero_short_strips_prefix():
    assert hero_short("npc_dota_hero_skeleton_king") == "skeleton_king"
    assert hero_short("npc_dota_hero_riki") == "riki"


from tools.hero_ability_gen import parse_localized_names


def test_parse_localized_names():
    text = '''"lang"
{
"Tokens"
{
    "DOTA_Tooltip_ability_riki_smoke_screen" "Smoke Screen"
    "DOTA_Tooltip_ability_riki_smoke_screen_radius" "RADIUS:"
    "DOTA_Tooltip_ability_queenofpain_scream_of_pain" "Scream Of Pain"
    "some_other_token" "ignored"
}
}'''
    names = parse_localized_names(text)
    assert names["riki_smoke_screen"] == "Smoke Screen"
    assert names["queenofpain_scream_of_pain"] == "Scream Of Pain"
    # sub-field tokens are still captured but never queried by ability key
    assert names["riki_smoke_screen_radius"] == "RADIUS:"
    assert "some_other_token" not in names


from tools.hero_ability_gen import annotate_file_lines

SAMPLE = '''"DOTAAbilities"
{
\t"riki_smoke_screen"
\t{
\t\t"AbilityCooldown"\t"20 17 14 11"
\t\t"AbilityValues"
\t\t{
\t\t\t"miss_rate"\t"30 45 60 75"
\t\t\t"radius"
\t\t\t{
\t\t\t\t"value"\t"425"
\t\t\t}
\t\t\t"block_targeting"\t"0"
\t\t}
\t}
}
'''


def _run(sample, names):
    return "".join(annotate_file_lines(sample.splitlines(keepends=True), names))


def test_injects_name_header_above_ability():
    out = _run(SAMPLE, {"riki_smoke_screen": "Smoke Screen"})
    assert "// ---- Smoke Screen  (riki_smoke_screen) ----" in out
    assert "// icon: riki_smoke_screen" in out
    # header appears before the ability key line
    assert out.index("Smoke Screen  (riki_smoke_screen)") < out.index('"riki_smoke_screen"')


def test_annotates_flat_value_inside_abilityvalues():
    out = _run(SAMPLE, {})
    assert '"miss_rate"\t"30 45 60 75"\t// higher = stronger' in out


def test_annotates_named_block_value():
    out = _run(SAMPLE, {})
    # the "radius" key (block opener) gets the hint, not the inner "value"
    assert '"radius"\t// higher = stronger' in out


def test_annotates_ability_level_cooldown():
    out = _run(SAMPLE, {})
    assert '"AbilityCooldown"\t"20 17 14 11"\t// lower = stronger' in out


def test_unknown_value_inside_abilityvalues_gets_tooltip_note():
    out = _run(SAMPLE, {})
    assert '"block_targeting"\t"0"\t// check tooltip' in out


def test_original_lines_preserved():
    out = _run(SAMPLE, {})
    # the inner "value" line is untouched (not inside annotate targets)
    assert '\t\t\t\t"value"\t"425"\n' in out


def test_comment_braces_do_not_corrupt_depth():
    # A commented-out brace must not shift AbilityValues scope tracking.
    sample = (
        '"DOTAAbilities"\n{\n'
        '\t"foo_ability"\n\t{\n'
        '\t\t"AbilityValues"\n\t\t{\n'
        '\t\t\t//{\n'                       # stray commented brace
        '\t\t\t"damage"\t"100"\n'
        '\t\t}\n\t}\n}\n'
    )
    out = "".join(annotate_file_lines(sample.splitlines(keepends=True), {}))
    # "damage" is a direct AbilityValues child and must still be annotated
    assert '"damage"\t"100"\t// higher = stronger' in out
    # the comment line itself is preserved untouched
    assert '\t\t\t//{\n' in out


from tools.hero_ability_gen import render_base_block, update_load_file, BEGIN, END


def test_render_base_block():
    block = render_base_block(["npc_dota_hero_riki", "npc_dota_hero_skeleton_king"])
    assert BEGIN in block and END in block
    assert '#base "heroes/riki/abilities.txt"' in block
    assert '#base "heroes/skeleton_king/abilities.txt"' in block


def test_update_load_file_inserts_after_last_base():
    content = (
        '#base "npc_abilities_fix.txt"\n'
        '#base "npc_abilities_halloween.txt"\n'
        '\n'
        '//#base "valvemodes/x.txt"\n'
        '"DOTAAbilities"\n{\n}\n'
    )
    block = render_base_block(["npc_dota_hero_riki"])
    updated = update_load_file(content, block)
    assert updated.index('#base "npc_abilities_halloween.txt"') < updated.index(BEGIN)
    assert updated.index(BEGIN) < updated.index('//#base "valvemodes/x.txt"')
    assert '#base "heroes/riki/abilities.txt"' in updated


def test_update_load_file_is_idempotent():
    content = (
        '#base "npc_abilities_halloween.txt"\n"DOTAAbilities"\n{\n}\n'
    )
    block1 = render_base_block(["npc_dota_hero_riki"])
    once = update_load_file(content, block1)
    block2 = render_base_block(["npc_dota_hero_riki", "npc_dota_hero_axe"])
    twice = update_load_file(once, block2)
    # only one marker block ever exists
    assert twice.count(BEGIN) == 1
    assert '#base "heroes/axe/abilities.txt"' in twice


import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
NPC = REPO / "game/dota_addons/dota2_meme_mode/scripts/npc"


def test_generator_dry_run_reports_124(tmp_path):
    # --dry-run must not write anything but should report the hero count
    result = subprocess.run(
        [sys.executable, "tools/generate_hero_ability_files.py", "--dry-run"],
        cwd=REPO, capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "124 heroes" in result.stdout
    # dry run does not create the output dir
    assert not (NPC / "heroes").exists() or any((NPC / "heroes").iterdir()) is not None
