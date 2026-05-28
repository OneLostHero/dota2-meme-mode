"""Pure helpers for generating per-hero ability override files (MGMod)."""

import re

# Keys where a LOWER number is stronger (resources you spend / waits).
LOWER_STRONGER = ("cooldown", "manacost", "mana_cost", "cast_point", "_cost")

# Keys where a HIGHER number is stronger (effect magnitudes). Checked first so
# compound keys like "cooldown_reduction" resolve to "higher".
HIGHER_STRONGER = (
    "damage", "duration", "radius", "range", "pct", "percent", "heal",
    "bonus", "count", "slow", "miss_rate", "armor", "reduction", "steal",
    "speed", "regen", "chance", "stun", "multiplier", "amount", "number",
    "lifesteal",
)


def direction_hint(key):
    """Return a tuning-direction string for an ability value key, or None."""
    k = key.lower()
    if any(token in k for token in HIGHER_STRONGER):
        return "higher = stronger"
    if any(token in k for token in LOWER_STRONGER):
        return "lower = stronger"
    return None


_ACTIVE_RE = re.compile(r'"(npc_dota_hero_[a-z0-9_]+)"\s+"1"')
_HERO_PREFIX = "npc_dota_hero_"


def parse_active_heroes(activelist_text):
    """Return hero keys whose whitelist value is "1", in file order."""
    return _ACTIVE_RE.findall(activelist_text)


def hero_short(hero_key):
    """npc_dota_hero_riki -> riki"""
    if hero_key.startswith(_HERO_PREFIX):
        return hero_key[len(_HERO_PREFIX):]
    return hero_key
