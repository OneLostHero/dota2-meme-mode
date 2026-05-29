# Flasaro Custom-Hero Framework + Boosted Upgrade Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the custom hero Flasaro spawn and render correctly by rebuilding his definition on the proven `BaseClass` pattern (with Sven's innate, no facets), then stop the boosted red-currency upgrades from appearing on the skill bar / consuming skill points.

**Architecture:** Dota 2 Source 2 custom game. Heroes are defined in KeyValues (`npc_heroes_custom.txt`); abilities/talents in `npc_abilities_custom.txt` (which `#base`-includes per-hero `heroes/<name>/abilities.txt`). Game logic is vscript Lua under `scripts/vscripts/`. There is **no automated test framework** — verification is (a) a KV brace/quote validator script and (b) the user play-testing in-game (`dota_launch_custom_game dota2_meme_mode dota`). The agent cannot launch the client.

**Tech Stack:** Valve KeyValues, Panorama (XML/CSS/JS), Lua (vscript), Python 3 (for the KV validator only), git.

**Deployment note:** the repo is live-linked into the Steam install via a directory junction, so edits take effect on the next custom-game launch — no copy step.

---

## Conventions used in this plan

**KV validator** (used as the "test" for every KeyValues change). Run from repo root:

```bash
python - "$@" <<'PY'
import sys
from pathlib import Path
ok_all=True
for f in sys.argv[1:]:
    t=Path(f).read_text(encoding="utf-8",errors="ignore"); depth=0; ok=True
    for ln in t.splitlines():
        c=ln.split("//",1)[0]
        if c.lstrip().startswith("#base"): continue
        if c.count('"')%2: ok=False
        depth+=c.count("{")-c.count("}")
    print(("OK " if ok and depth==0 else "BAD"), f"depth={depth}", f)
    ok_all = ok_all and ok and depth==0
sys.exit(0 if ok_all else 1)
PY
```

Expected output for a valid file: `OK depth=0 <path>`.

---

## Part A — Custom-hero framework (fixes spawn + portrait)

### Task A1: Rebuild Flasaro's hero definition on the BaseClass pattern

**Files:**
- Modify: `game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt` (replace the entire `npc_dota_hero_flasaro` block)

- [ ] **Step 1: Replace the Flasaro block**

Replace the whole `"npc_dota_hero_flasaro" { ... }` block with the following. Key changes vs. current: added `BaseClass`, `HeroID` 24→250, added `sven_vanquisher` as the innate (Ability7, matching how Sven defines it), removed the `Facets` block, added the unit fields from the working `aqua` template.

```
	//============================================================
	//  Flasaro  (custom hero, Dragon Knight base/look)
	//  Q antimage_blink | W riki_blink_strike | E sven_great_cleave
	//  R sven_gods_strength | Innate sven_vanquisher | Sven talent tree
	//============================================================
	"npc_dota_hero_flasaro"
	{
		"BaseClass"				"npc_dota_hero_dragon_knight"	// REQUIRED: inherits a real hero class so the hero spawns + renders. DK is untouched.
		"HeroID"				"250"							// high, unused id (recycled gap 24 did not spawn)
		"Enabled"				"1"
		"Team"					"Good"
		"TeamName"				"DOTA_TEAM_GOODGUYS"
		"AttributePrimary"		"DOTA_ATTRIBUTE_STRENGTH"

		// Look + voice (Dragon Knight)
		"Model"					"models/heroes/dragon_knight/dragon_knight.vmdl"
		"ModelScale"			"0.840000"
		"SoundSet"				"Hero_DragonKnight"
		"GibType"				"default"
		"Role"					"Carry,Durable,Initiator"
		"Complexity"			"1"
		"BotImplemented"		"0"

		// Abilities
		"Ability1"				"antimage_blink"				// Q
		"Ability2"				"riki_blink_strike"				// W
		"Ability3"				"sven_great_cleave"				// E
		"Ability4"				"generic_hidden"
		"Ability5"				"generic_hidden"
		"Ability6"				"sven_gods_strength"			// R (ult)
		"Ability7"				"sven_vanquisher"				// Innate (Sven's innate)
		"Ability10"				"special_bonus_unique_sven_5"
		"Ability11"				"special_bonus_attack_speed_15"
		"Ability12"				"special_bonus_unique_sven_3"
		"Ability13"				"special_bonus_unique_sven_8"
		"Ability14"				"special_bonus_unique_sven_6"
		"Ability15"				"special_bonus_unique_sven_7"
		"Ability16"				"special_bonus_unique_sven_2"
		"Ability17"				"special_bonus_unique_sven_4"

		// Attributes (Dragon Knight)
		"AttributeBaseStrength"			"21"
		"AttributeStrengthGain"			"3.600000"
		"AttributeBaseAgility"			"16"
		"AttributeAgilityGain"			"2.000000"
		"AttributeBaseIntelligence"		"18"
		"AttributeIntelligenceGain"		"1.700000"

		// Combat (Dragon Knight)
		"ArmorPhysical"			"0"
		"MagicalResistance"		"25"
		"AttackCapabilities"	"DOTA_UNIT_CAP_MELEE_ATTACK"
		"AttackDamageMin"		"34"
		"AttackDamageMax"		"40"
		"AttackDamageType"		"DAMAGE_TYPE_PHYSICAL"
		"AttackRate"			"1.600000"
		"AttackAnimationPoint"	"0.500000"
		"AttackAcquisitionRange"	"600"
		"AttackRange"			"150"
		"MovementSpeed"			"315"
		"MovementTurnRate"		"0.500000"
		"MovementCapabilities"	"DOTA_UNIT_CAP_MOVE_GROUND"
		"VisionDaytimeRange"	"1800"
		"VisionNighttimeRange"	"800"
		"StatusHealth"			"200"
		"StatusHealthRegen"		"0.25"
		"StatusMana"			"75"
		"StatusManaRegen"		"0.0"
		"BoundsHullName"		"DOTA_HULL_SIZE_HERO"

		// Classification
		"CombatClassAttack"			"DOTA_COMBAT_CLASS_ATTACK_BASIC"
		"CombatClassDefend"			"DOTA_COMBAT_CLASS_DEFEND_BASIC"
		"UnitRelationshipClass"		"DOTA_NPC_UNIT_RELATIONSHIP_TYPE_DEFAULT"
	}
```

- [ ] **Step 2: Validate the KV**

Run the KV validator (see Conventions) on:
`game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt`
Expected: `OK depth=0 ...`

- [ ] **Step 3: Confirm there is no leftover `Facets` key and the innate is present**

Run:
```bash
grep -nE 'Facets|flasaro_dragonblood|BaseClass|"HeroID"|sven_vanquisher' game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt
```
Expected: lines for `BaseClass`, `HeroID "250"`, `sven_vanquisher`; **no** `Facets` / `flasaro_dragonblood` lines.

- [ ] **Step 4: Commit**

```bash
git add game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt
git commit -m "feat(flasaro): rebuild on BaseClass pattern (dragon_knight base, HeroID 250, Sven innate, no facets)"
```

---

### Task A2: Remove the now-dead facet localization token

**Files:**
- Modify: `game/dota_addons/dota2_meme_mode/resource/addon_english.txt`

- [ ] **Step 1: Delete the facet tooltip line**

Remove this line (facets are gone, so the token is dead):
```
		"DOTA_Tooltip_Ability_flasaro_dragonblood"		"Dragon Blood"
```
Leave the other Flasaro tokens (`npc_dota_hero_flasaro`, `_bio`, `_npedesc1/2`, `_hype`) untouched.

- [ ] **Step 2: Validate the KV**

Run the KV validator on:
`game/dota_addons/dota2_meme_mode/resource/addon_english.txt`
Expected: `OK depth=0 ...`

- [ ] **Step 3: Commit**

```bash
git add game/dota_addons/dota2_meme_mode/resource/addon_english.txt
git commit -m "chore(flasaro): drop dead facet tooltip token"
```

---

### Task A3: User play-test checkpoint — Part A

This is a manual verification gate. No code.

- [ ] **Step 1: Ask the user to launch and test**

Ask the user to run `dota_launch_custom_game dota2_meme_mode dota`, enable **Custom Heroes** in setup, pick **Flasaro**, and confirm:
1. Flasaro spawns as a controllable hero with a populated ability bar.
2. His innate (Sven's `sven_vanquisher`) is present.
3. The pick-screen portrait renders (DK model) instead of black.
4. Dragon Knight is still independently pickable/playable.

- [ ] **Step 2: Branch on result**

- If all pass → Part A done; proceed to Part B.
- If the hero still does not spawn → capture the VConsole log and re-open diagnosis before Part B. Do NOT start Part B until Flasaro spawns, since Part B's in-game verification needs a playable Flasaro.

---

## Part B — Confine boosted upgrades to the left panel + red currency

> Part B is diagnosis-first: the exact fix location is unknown until Task B1 isolates it. Do Part B only after Task A3 passes.

### Task B1: Diagnose how boosted upgrades reach the skill bar / consume points

**Files (read-only investigation):**
- Read: `game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/plugins/boosted/plugin.lua`
- Read: `game/dota_addons/dota2_meme_mode/scripts/npc/npc_abilities_custom.txt` and a sample `heroes/<name>/abilities.txt`
- Read: `content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml`, `.../inspect_upgrades.xml` and their `.js`
- Compare against the original: `https://github.com/drteaspoon420/MGMod`

- [ ] **Step 1: Capture the current (broken) behavior precisely**

Ask the user (or use the existing screenshots) to confirm exactly which entries appear on the skill bar and whether leveling them spends a skill point or a talent point. Write the answer down in the task notes.

- [ ] **Step 2: Identify what the skill-bar entries are**

Run:
```bash
grep -rniE 'special_bonus|AbilityType|DOTA_ABILITY_TYPE' game/dota_addons/dota2_meme_mode/scripts/npc/heroes/tinker/abilities.txt | head -40
```
Determine whether the on-bar entries are real `special_bonus_*` talents or boosted upgrade pseudo-abilities, and how they are slotted.

- [ ] **Step 3: Diff fork vs. original for the boosted/ability-loading path**

Fetch the original repo's equivalents and compare (use `gh` or WebFetch on raw URLs under `https://raw.githubusercontent.com/drteaspoon420/MGMod/master/...`):
- `npc_abilities_custom.txt` (does the original `#base` the per-hero `heroes/` files the same way?)
- `plugin_system/plugins/boosted/plugin.lua`
- `panorama/.../upgrade.js`, `inspect_upgrades.js`

List every difference relevant to where upgrades render and whether they are registered as castable/levelable abilities.

- [ ] **Step 4: Write the findings + the chosen fix**

Append a short "Diagnosis" note to the design spec (`docs/superpowers/specs/2026-05-29-flasaro-custom-hero-and-boosted-upgrades-design.md`) stating: the root cause, the exact file(s)/setting to change, and why it confines upgrades to the left panel + red currency without touching the normal talent tree.

- [ ] **Step 5: Commit the diagnosis note**

```bash
git add docs/superpowers/specs/2026-05-29-flasaro-custom-hero-and-boosted-upgrades-design.md
git commit -m "docs(boosted): record diagnosis of upgrades leaking to skill bar"
```

---

### Task B2: Apply the targeted fix identified in B1

**Files:** determined by Task B1 (one of: `boosted/plugin.lua`, `boosted/settings.txt`/lists, or the upgrade Panorama files). Change the **smallest** surface that achieves the outcome.

- [ ] **Step 1: Make the change from the B1 diagnosis**

Implement exactly the fix recorded in Task B1 Step 4. Constraint: boosted upgrade entries must not be registered as castable/levelable hero abilities (that is what puts them on the bar and lets them eat points); they must surface only through the left upgrade panel and cost red currency. Do not modify the normal talent (`special_bonus`) tree behavior.

- [ ] **Step 2: Validate any KV files touched**

Run the KV validator on any `.txt` files changed.
Expected: `OK depth=0 ...` for each.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix(boosted): confine red-currency upgrades to the left panel (off the skill bar, no skill points)"
```

---

### Task B3: User play-test checkpoint — Part B

Manual verification gate. No code.

- [ ] **Step 1: Ask the user to launch and test**

Ask the user to start a game with **Boosted** + **Custom Heroes** enabled and confirm:
1. Red-currency upgrades appear only in the left-side upgrade panel.
2. They cost red currency.
3. They are absent from the skill bar.
4. Leveling them does not consume skill/talent points.
5. The normal talent tree (10/15/20/25) still works.

- [ ] **Step 2: Branch on result**

- If all pass → both parts complete; push the branch / open for review per the repo's solo-ship workflow.
- If not → return to Task B1 with the new log/screenshot; re-diagnose before another fix attempt (do not stack blind fixes).

---

## Self-Review

**Spec coverage:**
- Spec Part A (BaseClass, high HeroID, unit fields, drop facets, Sven innate, keep kit/precache/herolist/fallback) → Task A1 (+ A2 token cleanup, A3 verify). ✓
- Spec Part B (diagnose vs original, confine to left panel + red currency, talents untouched) → Tasks B1/B2/B3. ✓
- Spec success criteria → encoded in the A3 and B3 checklists. ✓

**Placeholder scan:** Part A steps contain the full literal KV block and exact commands. Part B is intentionally diagnosis-gated: B1 produces the concrete fix that B2 applies — this is correct for a debugging task, not a hidden placeholder; the *outcome* and *constraints* are fully specified.

**Type/name consistency:** Hero name `npc_dota_hero_flasaro`, base `npc_dota_hero_dragon_knight`, innate `sven_vanquisher`, HeroID `250` are used consistently. Validator invocation is identical across tasks.

**Note on "no facets":** per the user, facets are removed from the live client; the working `aqua` reference has no `Facets` block, so A1 omits it. If a future play-test shows the client still requires a facet, that is a one-line re-add — but the proven reference says omit.
