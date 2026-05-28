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
