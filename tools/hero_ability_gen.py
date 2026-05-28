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


_LOC_RE = re.compile(r'"DOTA_Tooltip_ability_([A-Za-z0-9_]+)"\s+"([^"]*)"')


def parse_localized_names(loc_text):
    """Map ability-token -> display string from a *_english.txt tokens file.

    Captures every DOTA_Tooltip_ability_* token. Callers look up exact ability
    keys (e.g. "riki_smoke_screen"), so sub-field tokens never collide in use.
    """
    return {key: value for key, value in _LOC_RE.findall(loc_text)}


_ONE_TAB_KEY = re.compile(r'^\t"([^"]+)"\s*$')          # ability header candidate
_FLAT_KV = re.compile(r'^\t+"([^"]+)"\s+"([^"]*)"\s*$')  # "key"  "value"
_NAMED_KEY = re.compile(r'^\t+"([^"]+)"\s*$')            # "key"  (block opener)

_COST_FIELDS = ("AbilityCooldown", "AbilityManaCost", "AbilityCastPoint")


def _next_real_is_brace(lines, i):
    """True if the next non-blank, non-comment line after i opens a brace."""
    for j in range(i + 1, len(lines)):
        s = lines[j].strip()
        if s == "" or s.startswith("//"):
            continue
        return s.startswith("{")
    return False


def _append_comment(line, text):
    """Append a trailing // comment, preserving the line's newline."""
    newline = "\n" if line.endswith("\n") else ""
    return line.rstrip("\n").rstrip() + f"\t// {text}{newline}"


def annotate_file_lines(lines, names):
    """Return a new list of lines with name headers and direction comments."""
    out = []
    depth = 0
    values_depth = None      # brace depth at which AbilityValues *content* lives
    pending_av = False       # saw "AbilityValues", waiting for its "{"

    for i, line in enumerate(lines):
        bare = line.rstrip("\n")
        inside_av = values_depth is not None and depth == values_depth

        # (a) ability-name header above a one-tab key that opens a block
        header = _ONE_TAB_KEY.match(bare)
        if header and _next_real_is_brace(lines, i):
            key = header.group(1)
            name = names.get(key)
            out.append(f"\t// ---- {name or key}  ({key}) ----\n")
            if name:
                out.append(f"\t// icon: {key}\n")

        # (b) value annotation
        annotated = line
        flat = _FLAT_KV.match(bare)
        if flat:
            key = flat.group(1)
            if inside_av:
                annotated = _append_comment(line, direction_hint(key) or "check tooltip")
            elif key in _COST_FIELDS:
                hint = direction_hint(key)
                if hint:
                    annotated = _append_comment(line, hint)
        else:
            named = _NAMED_KEY.match(bare)
            # a named block value inside AbilityValues (e.g. "radius" { ... })
            if named and inside_av and _next_real_is_brace(lines, i):
                key = named.group(1)
                annotated = _append_comment(line, direction_hint(key) or "check tooltip")
        out.append(annotated)

        # (c) brace + AbilityValues scope tracking (skip comment lines)
        if not bare.lstrip().startswith("//"):
            _m = _NAMED_KEY.match(bare)
            if _m and _m.group(1) == "AbilityValues":
                pending_av = True
            if "{" in line and pending_av:
                values_depth = depth + 1
                pending_av = False
            depth += line.count("{") - line.count("}")
            if values_depth is not None and depth < values_depth:
                values_depth = None

    return out
