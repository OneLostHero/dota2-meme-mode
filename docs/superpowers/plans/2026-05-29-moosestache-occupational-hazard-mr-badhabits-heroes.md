# Moosestache, Occupational Hazard & Mr. BadHabits — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three new "Frankenstein" custom heroes — assembled from existing Valve abilities — to the meme-mode hero pool, following the proven Flasaro/OneLostHero pipeline.

**Architecture:** Each hero is a `DOTAHeroes` KV block with a real `BaseClass`, a high unused `HeroID`, four borrowed abilities + one borrowed innate, and a talent tree built from **real stock talent tokens** (verified to be referenced by the held abilities, so they actually function). Almost everything is KV-only. A small amount of Lua is added only for the few Aghanim's effects that are not native to a borrowed ability. Portrait/herolist/precache/toggle/localization wiring matches the existing two custom heroes.

**Tech Stack:** Dota 2 KeyValues (`.txt`), Lua (vscripts), Panorama (JS/CSS) for portraits. Tested by launching the addon as a real custom game (`dota_launch_custom_game dota2_meme_mode dota`) — there is no offline unit-test harness for Dota content, so each phase ends with an in-client verification checklist instead of an automated test.

**Spec:** `docs/superpowers/specs/2026-05-29-moosestache-occupational-hazard-custom-heroes-design.md`
**Reference (authoritative on-disk stock dump):** `docs/reference/npc/_heroes/npc_dota_hero_<base>.txt`

---

## File Structure

**Modified (shared, one block/line added per hero):**
- `game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt` — three new `DOTAHeroes` blocks.
- `game/dota_addons/dota2_meme_mode/scripts/npc/herolist.txt` — three whitelist lines.
- `game/dota_addons/dota2_meme_mode/resource/addon_english.txt` — name/bio tokens per hero.
- `game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/plugins/custom_heroes/plugin.lua` — three names in `custom_heroes`.
- `content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/custom_hero_portrait.js` — three names in `CUSTOM_SHORT`.
- `content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/custom_hero_portrait.css` — `.PrecacheImg_*` lines (only after PNGs exist).
- `game/dota_addons/dota2_meme_mode/scripts/npc/npc_abilities_custom.txt` — `#base` includes for the tiny-Lua aghs ability files.

**Created (tiny-Lua aghs only):**
- `game/dota_addons/dota2_meme_mode/scripts/npc/abilities/customheroes_aghs.txt` — hidden passive abilities that carry the custom aghs/shard modifiers.
- `game/dota_addons/dota2_meme_mode/scripts/vscripts/abilities/customheroes/*.lua` — the modifier logic.

**Precache:** `addon_game_mode.lua` already loops every entry in `npc_heroes_custom.txt`, so new heroes are precached automatically — no edit needed (verified in Phase 1).

---

## Locked design data (resolved against the stock dump — no guessing during execution)

**Internal ability names (confirmed present in `docs/reference/npc/_heroes/`):**

| Hero | Q | W | E | R (ult) | Innate |
|---|---|---|---|---|---|
| Moosestache | `spirit_breaker_charge_of_darkness` | `razor_static_link` | `bounty_hunter_jinada` | `faceless_void_chronosphere` | `faceless_void_distortion_field` |
| Occupational Hazard | `death_prophet_spirit_siphon` | `skeleton_king_bone_guard` | `necrolyte_heartstopper_aura` | `lion_finger_of_death` | `razor_storm_surge` |
| Mr. BadHabits | `tiny_toss` | `bristleback_quill_spray` | `pudge_flesh_heap` *(="Meat Shield")* | `rubick_spell_steal` | `pudge_innate_graft_flesh` *(="Flesh Heap")* |

**Bases / look:** Moosestache → `npc_dota_hero_bloodseeker`, `models/heroes/bloodseeker/bloodseeker.vmdl`, `Hero_Bloodseeker`, Agility, HeroID **252**. Occupational Hazard → `npc_dota_hero_necrolyte`, `models/heroes/necrolyte/necrolyte.vmdl`, `Hero_Necrolyte`, Intelligence, HeroID **253**. Mr. BadHabits → `npc_dota_hero_treant`, `models/heroes/treant/treant.vmdl`, `Hero_Treant`, Strength, HeroID **254**.

**Talent tokens (verified each is referenced by a held ability's KV, so it functions):**

Moosestache `Ability10..17`:
```
special_bonus_unique_bounty_hunter            // 10 L  Jinada
special_bonus_movement_speed_30               // 10 R
special_bonus_unique_razor_static_link_aspd   // 15 L  Static Link
special_bonus_unique_spirit_breaker_4         // 15 R  Charge of Darkness
special_bonus_unique_bounty_hunter_4          // 20 L  Jinada
special_bonus_attack_damage_40                // 20 R
special_bonus_unique_bounty_hunter_jinada_no_cooldown  // 25 L  Jinada
special_bonus_unique_razor                    // 25 R  Static Link
```
Occupational Hazard `Ability10..17`:
```
special_bonus_unique_necrophos_2              // 10 L  Heart Stopper
special_bonus_unique_death_prophet_5          // 10 R  Spirit Siphon
special_bonus_unique_necrophos_5              // 15 L  Heart Stopper
special_bonus_unique_death_prophet_3          // 15 R  Spirit Siphon
special_bonus_unique_razor_storm_surge_damage_and_slow // 20 L  Storm Surge (innate)
special_bonus_health_250                      // 20 R
special_bonus_unique_lion_8                   // 25 L  Finger of Death
special_bonus_magic_resistance_10             // 25 R
```
Mr. BadHabits `Ability10..17`:
```
special_bonus_unique_bristleback_2            // 10 L  Quill Spray
special_bonus_health_250                      // 10 R
special_bonus_unique_tiny_2                   // 15 L  Toss
special_bonus_unique_pudge_1                  // 15 R  Meat Shield (block x1.5)
special_bonus_unique_tiny_5                   // 20 L  Toss
special_bonus_strength_12                     // 20 R
special_bonus_status_resistance_10            // 25 L
special_bonus_attack_damage_60                // 25 R
```

> Generic stat token names (`special_bonus_movement_speed_30`, `_health_250`, `_strength_12`, `_attack_damage_40/60`, `_magic_resistance_10`, `_status_resistance_10`) are taken from `docs/reference/npc/__npc_abilities.txt`. If any exact value-name is absent in-build, substitute the nearest existing one from that file (Step in Phase 4 verifies).

---

## Phase 1 — Moosestache (pure KV)

**Files:** `npc_heroes_custom.txt`, `herolist.txt`, `addon_english.txt`, `plugin.lua`

- [ ] **Step 1: Add the hero block to `npc_heroes_custom.txt`**

Insert this block inside `"DOTAHeroes" { ... }`, after the OneLostHero block (before the file's final closing `}`). For the attribute/combat/classification values, **copy the real numbers** from `docs/reference/npc/_heroes/npc_dota_hero_bloodseeker.txt` (the `AttributeBase*`, `*Gain`, `ArmorPhysical`, `MagicalResistance`, `AttackCapabilities`, `AttackDamageMin/Max`, `AttackRate`, `AttackAnimationPoint`, `AttackRange`, `MovementSpeed`, `MovementTurnRate`, `StatusHealth*`, `StatusMana*`, `VisionDaytimeRange/Nighttime`, `BoundsHullName` fields) — same approach used for Flasaro/OneLostHero.

```
	//============================================================
	//  Moosestache  (custom hero, Bloodseeker base/look)
	//  Q Charge of Darkness | W Static Link | E Jinada
	//  R Chronosphere | Innate Distortion Field
	//  Momentum bruiser-carry: charge in, leech attack damage, lock the fight, crit.
	//============================================================
	"npc_dota_hero_moosestache"
	{
		"BaseClass"				"npc_dota_hero_bloodseeker"		// REQUIRED: real base class so the hero spawns + renders. Bloodseeker is untouched.
		"HeroID"				"252"							// high, unused id (250 Flasaro, 251 OneLostHero)
		"Enabled"				"1"
		"Team"					"Good"
		"TeamName"				"DOTA_TEAM_GOODGUYS"
		"AttributePrimary"		"DOTA_ATTRIBUTE_AGILITY"

		"Model"					"models/heroes/bloodseeker/bloodseeker.vmdl"
		"ModelScale"			"1.000000"
		"SoundSet"				"Hero_Bloodseeker"
		"GibType"				"default"
		"Role"					"Carry,Initiator,Disabler,Durable"
		"Complexity"			"2"
		"BotImplemented"		"0"

		// Abilities
		"Ability1"				"spirit_breaker_charge_of_darkness"		// Q
		"Ability2"				"razor_static_link"						// W
		"Ability3"				"bounty_hunter_jinada"					// E (passive)
		"Ability4"				"generic_hidden"
		"Ability5"				"generic_hidden"
		"Ability6"				"faceless_void_chronosphere"			// R (ult)
		"Ability7"				"faceless_void_distortion_field"		// Innate

		// Talents (real stock tokens, verified wired to held abilities)
		"Ability10"				"special_bonus_unique_bounty_hunter"
		"Ability11"				"special_bonus_movement_speed_30"
		"Ability12"				"special_bonus_unique_razor_static_link_aspd"
		"Ability13"				"special_bonus_unique_spirit_breaker_4"
		"Ability14"				"special_bonus_unique_bounty_hunter_4"
		"Ability15"				"special_bonus_attack_damage_40"
		"Ability16"				"special_bonus_unique_bounty_hunter_jinada_no_cooldown"
		"Ability17"				"special_bonus_unique_razor"

		// >>> copy AttributeBase*/Gain + combat + classification block from
		//     docs/reference/npc/_heroes/npc_dota_hero_bloodseeker.txt here <<<
	}
```

- [ ] **Step 2: Add the herolist whitelist line**

In `scripts/npc/herolist.txt`, after the `npc_dota_hero_onelosthero` line (line ~131):
```
	"npc_dota_hero_moosestache"		"1"
```

- [ ] **Step 3: Add localization tokens to `addon_english.txt`**

After the existing OneLostHero hero-name block (near line 20), add:
```
		"npc_dota_hero_moosestache"			"Moosestache"
		"npc_dota_hero_moosestache_bio"		"A relentless momentum bruiser who charges across the battlefield, latches onto his prey to drain its strength, and freezes time to finish the job."
		"npc_dota_hero_moosestache_hype"	"You can run. You'll just die tired."
```
(No per-ability tooltips needed — borrowed abilities reuse their source localization.)

- [ ] **Step 4: Register in the Custom Heroes toggle**

In `plugin.lua`, add to `CustomHeroesPlugin.custom_heroes`:
```lua
    "npc_dota_hero_moosestache",
```

- [ ] **Step 5: Commit**

```bash
git add game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt \
        game/dota_addons/dota2_meme_mode/scripts/npc/herolist.txt \
        game/dota_addons/dota2_meme_mode/resource/addon_english.txt \
        game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/plugins/custom_heroes/plugin.lua
git commit -m "feat(moosestache): add custom hero (Bloodseeker base, charge/link/jinada/chrono)"
```

---

## Phase 2 — Occupational Hazard (pure KV)

**Files:** same four as Phase 1.

- [ ] **Step 1: Add the hero block to `npc_heroes_custom.txt`** (after the Moosestache block). Copy attribute/combat/classification values from `docs/reference/npc/_heroes/npc_dota_hero_necrolyte.txt`.

```
	//============================================================
	//  Occupational Hazard  (custom hero, Necrophos base/look)
	//  Q Spirit Siphon | W Bone Guard | E Heart Stopper Aura
	//  R Finger of Death | Innate Storm Surge
	//  Necro-caster/summoner/drain: aura attrition, skeletons, siphon, execute.
	//============================================================
	"npc_dota_hero_occupational_hazard"
	{
		"BaseClass"				"npc_dota_hero_necrolyte"
		"HeroID"				"253"
		"Enabled"				"1"
		"Team"					"Good"
		"TeamName"				"DOTA_TEAM_GOODGUYS"
		"AttributePrimary"		"DOTA_ATTRIBUTE_INTELLECT"

		"Model"					"models/heroes/necrolyte/necrolyte.vmdl"
		"ModelScale"			"1.000000"
		"SoundSet"				"Hero_Necrolyte"
		"GibType"				"default"
		"Role"					"Nuker,Disabler,Pusher,Durable"
		"Complexity"			"2"
		"BotImplemented"		"0"

		"Ability1"				"death_prophet_spirit_siphon"		// Q
		"Ability2"				"skeleton_king_bone_guard"			// W
		"Ability3"				"necrolyte_heartstopper_aura"		// E (passive aura)
		"Ability4"				"generic_hidden"
		"Ability5"				"generic_hidden"
		"Ability6"				"lion_finger_of_death"				// R (ult)
		"Ability7"				"razor_storm_surge"					// Innate

		"Ability10"				"special_bonus_unique_necrophos_2"
		"Ability11"				"special_bonus_unique_death_prophet_5"
		"Ability12"				"special_bonus_unique_necrophos_5"
		"Ability13"				"special_bonus_unique_death_prophet_3"
		"Ability14"				"special_bonus_unique_razor_storm_surge_damage_and_slow"
		"Ability15"				"special_bonus_health_250"
		"Ability16"				"special_bonus_unique_lion_8"
		"Ability17"				"special_bonus_magic_resistance_10"

		// >>> copy AttributeBase*/Gain + combat + classification block from
		//     docs/reference/npc/_heroes/npc_dota_hero_necrolyte.txt here <<<
	}
```

- [ ] **Step 2: herolist line** — add `"npc_dota_hero_occupational_hazard"		"1"`.

- [ ] **Step 3: Localization** — add:
```
		"npc_dota_hero_occupational_hazard"			"Occupational Hazard"
		"npc_dota_hero_occupational_hazard_bio"		"A grim attritionist who melts foes with a deathly aura, raises skeletal labor, siphons the life from his enemies, and points a single fatal finger at the survivor."
		"npc_dota_hero_occupational_hazard_hype"	"Death is just the cost of doing business."
```

- [ ] **Step 4: Toggle** — add `"npc_dota_hero_occupational_hazard",` to `plugin.lua`.

- [ ] **Step 5: Commit**
```bash
git add game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt \
        game/dota_addons/dota2_meme_mode/scripts/npc/herolist.txt \
        game/dota_addons/dota2_meme_mode/resource/addon_english.txt \
        game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/plugins/custom_heroes/plugin.lua
git commit -m "feat(occupational-hazard): add custom hero (Necrophos base, siphon/boneguard/heartstopper/finger)"
```

---

## Phase 3 — Mr. BadHabits (pure KV)

**Files:** same four.

- [ ] **Step 1: Add the hero block** (after Occupational Hazard). Copy attribute/combat/classification values from `docs/reference/npc/_heroes/npc_dota_hero_treant.txt`.

```
	//============================================================
	//  Mr. BadHabits  (custom hero, Treant Protector base/look)
	//  Q Toss | W Quill Spray | E Meat Shield (pudge_flesh_heap)
	//  R Spell Steal | Innate Flesh Heap (pudge_innate_graft_flesh)
	//  Tanky punisher-thief: toss them around, bleed them behind a shield, steal their best spell.
	//============================================================
	"npc_dota_hero_mr_badhabits"
	{
		"BaseClass"				"npc_dota_hero_treant"
		"HeroID"				"254"
		"Enabled"				"1"
		"Team"					"Good"
		"TeamName"				"DOTA_TEAM_GOODGUYS"
		"AttributePrimary"		"DOTA_ATTRIBUTE_STRENGTH"

		"Model"					"models/heroes/treant/treant.vmdl"
		"ModelScale"			"1.000000"
		"SoundSet"				"Hero_Treant"
		"GibType"				"default"
		"Role"					"Durable,Disabler,Initiator,Nuker"
		"Complexity"			"2"
		"BotImplemented"		"0"

		"Ability1"				"tiny_toss"					// Q
		"Ability2"				"bristleback_quill_spray"	// W
		"Ability3"				"pudge_flesh_heap"			// E (Meat Shield: damage-block active)
		"Ability4"				"generic_hidden"
		"Ability5"				"generic_hidden"
		"Ability6"				"rubick_spell_steal"		// R (ult)
		"Ability7"				"pudge_innate_graft_flesh"	// Innate (Flesh Heap: +STR on kills)

		"Ability10"				"special_bonus_unique_bristleback_2"
		"Ability11"				"special_bonus_health_250"
		"Ability12"				"special_bonus_unique_tiny_2"
		"Ability13"				"special_bonus_unique_pudge_1"
		"Ability14"				"special_bonus_unique_tiny_5"
		"Ability15"				"special_bonus_strength_12"
		"Ability16"				"special_bonus_status_resistance_10"
		"Ability17"				"special_bonus_attack_damage_60"

		// >>> copy AttributeBase*/Gain + combat + classification block from
		//     docs/reference/npc/_heroes/npc_dota_hero_treant.txt here <<<
	}
```

- [ ] **Step 2: herolist line** — add `"npc_dota_hero_mr_badhabits"		"1"`.

- [ ] **Step 3: Localization** — add:
```
		"npc_dota_hero_mr_badhabits"		"Mr. BadHabits"
		"npc_dota_hero_mr_badhabits_bio"	"An immovable nuisance who hurls his enemies where he pleases, grinds them down with a spray of quills from behind a wall of meat, and helps himself to whatever spell they were saving."
		"npc_dota_hero_mr_badhabits_hype"	"Old habits die hard. So do you."
```

- [ ] **Step 4: Toggle** — add `"npc_dota_hero_mr_badhabits",` to `plugin.lua`.

- [ ] **Step 5: Commit**
```bash
git add game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt \
        game/dota_addons/dota2_meme_mode/scripts/npc/herolist.txt \
        game/dota_addons/dota2_meme_mode/resource/addon_english.txt \
        game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/plugins/custom_heroes/plugin.lua
git commit -m "feat(mr-badhabits): add custom hero (Treant base, toss/quill/meatshield/spellsteal)"
```

---

## Phase 4 — First in-client verification (all three, pure-KV state)

This is the critical gate: confirm the three heroes spawn, their abilities/innates/talents work, and there are no Lua/KV load errors — **before** adding any aghs Lua.

- [ ] **Step 1: Launch the addon as a real custom game**

From the Dota 2 console (not Hammer — Hammer doesn't run the addon Lua):
```
dota_launch_custom_game dota2_meme_mode dota
```
Enable the **Custom Heroes** toggle on the setup screen.

- [ ] **Step 2: Per-hero spawn + ability check**

For each of Moosestache, Occupational Hazard, Mr. BadHabits: pick the hero, confirm it spawns (not a black/error model), and watch the console for errors during load. Expected: hero spawns with the Bloodseeker / Necrophos / Treant look; no `Unknown ability`, no `KeyValues` parse error, no Lua error.

- [ ] **Step 3: Per-ability + innate + talent check**

Level each ability and cast it; confirm the innate is present (Distortion Field aura ring / Storm Surge proc on being hit / Flesh Heap STR gain on a nearby kill); open the talent tree and confirm all 8 talents show a real name + value (no raw `{s:...}` tokens, no blank rows). Note any ability that errors or any talent that shows blank.

- [ ] **Step 4: Record results**

If everything passes, note it and proceed. If a borrowed ability/innate errors on the non-native carrier (most likely candidates per the spec: Bone Guard skeletons, Toss without Tiny, an innate that won't level), record the exact console error — the fix is hero-specific and handled as a follow-up before Phase 5.

- [ ] **Step 5: Commit** (only if any KV fix was needed in Steps 2–4)
```bash
git add -A && git commit -m "fix(custom-heroes): resolve borrowed-ability issues found in first in-client test"
```

---

## Phase 5 — Aghanim's Scepter & Shard

Two ults upgrade natively (KV-only, verified here); the rest are small Lua modifiers gated on `HasScepter()` / `HasShard()`.

### Native scepter verification (no code)

- [ ] **Step 1: Verify Finger of Death + Spell Steal scepters fire**

In-client, give Occupational Hazard and Mr. BadHabits an Aghanim's Scepter (`-givebots item_ultimate_scepter` / shop) and confirm the upgrade applies: Finger of Death cooldown drops / damage rises; Spell Steal cooldown drops and a stolen spell comes pre-upgraded. Watch for the **facet caveat** (spec): if Finger's scepter path is dead because it migrated to `facet_lion_fist_of_death`, note it — its fix is the tiny-Lua numeric scepter in Step 5.

### Tiny-Lua aghs effects

- [ ] **Step 2: Create the aghs ability file `abilities/customheroes_aghs.txt`**

Three hidden passive abilities, one per custom effect, each attaching a Lua modifier. They occupy no visible slot — attach them by adding to each hero's block (replace one `generic_hidden` in `Ability4`). Content:
```
"DOTAAbilities"
{
	"moosestache_chrono_scepter"
	{
		"BaseClass"				"ability_lua"
		"ScriptFile"			"abilities/customheroes/moosestache_chrono_scepter.lua"
		"AbilityBehavior"		"DOTA_ABILITY_BEHAVIOR_PASSIVE | DOTA_ABILITY_BEHAVIOR_HIDDEN | DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE"
		"AbilityValues"
		{
			"scepter_cooldown_reduction"	"30"
		}
	}
	"occhazard_siphon_shard"
	{
		"BaseClass"				"ability_lua"
		"ScriptFile"			"abilities/customheroes/occhazard_siphon_shard.lua"
		"AbilityBehavior"		"DOTA_ABILITY_BEHAVIOR_PASSIVE | DOTA_ABILITY_BEHAVIOR_HIDDEN | DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE"
		"AbilityValues"
		{
			"shard_self_heal_pct"	"100"
		}
	}
	"badhabits_meatshield_shard"
	{
		"BaseClass"				"ability_lua"
		"ScriptFile"			"abilities/customheroes/badhabits_meatshield_shard.lua"
		"AbilityBehavior"		"DOTA_ABILITY_BEHAVIOR_PASSIVE | DOTA_ABILITY_BEHAVIOR_HIDDEN | DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE"
		"AbilityValues"
		{
			"shard_reflect_pct"	"25"
		}
	}
}
```

- [ ] **Step 3: Include the file in `npc_abilities_custom.txt`**

Add after the OneLostHero `#base` lines (line ~15):
```
#base "abilities/customheroes_aghs.txt"
```

- [ ] **Step 4: Wire each hidden ability into its hero**

In `npc_heroes_custom.txt`, change `Ability4` from `generic_hidden` to the hero's hidden aghs ability:
- Moosestache `Ability4` → `moosestache_chrono_scepter`
- Occupational Hazard `Ability4` → `occhazard_siphon_shard`
- Mr. BadHabits `Ability4` → `badhabits_meatshield_shard`

- [ ] **Step 5: Implement `moosestache_chrono_scepter.lua` (Scepter → Chronosphere)**

> **Design note / flagged adjustment:** "allies can act inside Chronosphere" turned out **not** tiny (Chronosphere's freeze is applied per-unit; intercepting it for allies is involved). The feasible, genuinely-small Scepter is a **Chronosphere cooldown reduction** via this passive. Implement that; surface the swap to the user at handoff. The reflect/heal shards below are likewise scoped small.

`scripts/vscripts/abilities/customheroes/moosestache_chrono_scepter.lua` — an intrinsic hidden modifier that returns a constant cooldown reduction for Chronosphere only while the hero holds a Scepter:
```lua
moosestache_chrono_scepter = class({})
LinkLuaModifier("modifier_moosestache_chrono_scepter", "abilities/customheroes/moosestache_chrono_scepter.lua", LUA_MODIFIER_MOTION_NONE)
function moosestache_chrono_scepter:GetIntrinsicModifierName() return "modifier_moosestache_chrono_scepter" end

modifier_moosestache_chrono_scepter = class({})
function modifier_moosestache_chrono_scepter:IsHidden() return true end
function modifier_moosestache_chrono_scepter:IsPurgable() return false end
function modifier_moosestache_chrono_scepter:OnCreated()
	self.cdr = self:GetAbility():GetSpecialValueFor("scepter_cooldown_reduction")
end
function modifier_moosestache_chrono_scepter:DeclareFunctions()
	return { MODIFIER_PROPERTY_COOLDOWN_REDUCTION_CONSTANT }
end
function modifier_moosestache_chrono_scepter:GetModifierConstantCooldownReductionAbility(p)
	if not self:GetParent():HasScepter() then return 0 end
	if p and p.ability and p.ability:GetAbilityName() == "faceless_void_chronosphere" then
		return self.cdr
	end
	return 0
end
```
> If `MODIFIER_PROPERTY_COOLDOWN_REDUCTION_CONSTANT` does not key per-ability in this build (Step 8 verifies), fall back to returning `self.cdr` unconditionally while the Scepter is held (a flat global CDR is acceptable since Chronosphere is the hero's only long-cooldown ult).

- [ ] **Step 6: Implement `badhabits_meatshield_shard.lua` (Shard → Meat Shield reflect)**

`scripts/vscripts/abilities/customheroes/badhabits_meatshield_shard.lua` — intrinsic hidden modifier that, while the hero has Shard **and** the stock `modifier_pudge_flesh_heap` (the damage-block buff) is active, reflects a % of incoming damage back as magic damage:
```lua
badhabits_meatshield_shard = class({})
LinkLuaModifier("modifier_badhabits_meatshield_shard", "abilities/customheroes/badhabits_meatshield_shard.lua", LUA_MODIFIER_MOTION_NONE)
function badhabits_meatshield_shard:GetIntrinsicModifierName() return "modifier_badhabits_meatshield_shard" end

modifier_badhabits_meatshield_shard = class({})
function modifier_badhabits_meatshield_shard:IsHidden() return true end
function modifier_badhabits_meatshield_shard:IsPurgable() return false end
function modifier_badhabits_meatshield_shard:DeclareFunctions()
	return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end
function modifier_badhabits_meatshield_shard:OnTakeDamage(kv)
	if not IsServer() then return end
	local me = self:GetParent()
	if kv.unit ~= me then return end
	if not me:HasShard() then return end
	if not me:HasModifier("modifier_pudge_flesh_heap") then return end
	local attacker = kv.attacker
	if not attacker or attacker:GetTeamNumber() == me:GetTeamNumber() then return end
	local pct = self:GetAbility():GetSpecialValueFor("shard_reflect_pct") / 100.0
	ApplyDamage({ victim = attacker, attacker = me, damage = kv.original_damage * pct,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() })
end
```
> Confirm the stock damage-block buff's exact modifier name in-client (likely `modifier_pudge_flesh_heap`); correct the string if the dump differs.

- [ ] **Step 7: Implement `occhazard_siphon_shard.lua` (Shard → Spirit Siphon self-heal)**

> **Feasibility note:** Spirit Siphon is enemy-targeted; a true "cast on self" requires changing the stock cast filter, which mutates the shared ability. The tiny, non-mutating form: while the hero has Shard, **heal the caster for a % of the damage Spirit Siphon deals**. Implement as an intrinsic modifier listening for the siphon's damage authored by this hero:
```lua
occhazard_siphon_shard = class({})
LinkLuaModifier("modifier_occhazard_siphon_shard", "abilities/customheroes/occhazard_siphon_shard.lua", LUA_MODIFIER_MOTION_NONE)
function occhazard_siphon_shard:GetIntrinsicModifierName() return "modifier_occhazard_siphon_shard" end

modifier_occhazard_siphon_shard = class({})
function modifier_occhazard_siphon_shard:IsHidden() return true end
function modifier_occhazard_siphon_shard:IsPurgable() return false end
function modifier_occhazard_siphon_shard:DeclareFunctions()
	return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end
function modifier_occhazard_siphon_shard:OnTakeDamage(kv)
	if not IsServer() then return end
	local me = self:GetParent()
	if not me:HasShard() then return end
	if kv.attacker ~= me then return end
	if not kv.inflictor or kv.inflictor:GetAbilityName() ~= "death_prophet_spirit_siphon" then return end
	local pct = self:GetAbility():GetSpecialValueFor("shard_self_heal_pct") / 100.0
	me:Heal(kv.damage * pct, me)
end
```

- [ ] **Step 8: In-client aghs verification + commit**

Launch, give each hero Scepter then Shard, and confirm: Moosestache Chronosphere cooldown is reduced with Scepter; Mr. BadHabits reflects damage while Meat Shield is up with Shard; Occupational Hazard heals from Spirit Siphon damage with Shard. Fix any modifier-name/property mismatch found, then:
```bash
git add game/dota_addons/dota2_meme_mode/scripts/npc/npc_abilities_custom.txt \
        game/dota_addons/dota2_meme_mode/scripts/npc/npc_heroes_custom.txt \
        game/dota_addons/dota2_meme_mode/scripts/npc/abilities/customheroes_aghs.txt \
        game/dota_addons/dota2_meme_mode/scripts/vscripts/abilities/customheroes/
git commit -m "feat(custom-heroes): aghs scepter/shard effects (chrono CDR, meatshield reflect, siphon self-heal)"
```

---

## Phase 6 — Portraits (art-gated) + final pass

- [ ] **Step 1: Ship placeholder portrait PNGs** for each hero (a splash/concept render is fine to start), at all four paths per the guide:
```
content/.../panorama/images/heroes/npc_dota_hero_<name>.png
content/.../panorama/images/heroes/selection/npc_dota_hero_<name>.png
content/.../panorama/images/heroes/icons/npc_dota_hero_<name>.png
content/.../panorama/images/heroes/crops/npc_dota_hero_<name>.png
```
for `<name>` in `moosestache`, `occupational_hazard`, `mr_badhabits`.

- [ ] **Step 2: Register short names in `custom_hero_portrait.js`** `CUSTOM_SHORT`:
```js
    "moosestache": true,
    "occupational_hazard": true,
    "mr_badhabits": true,
```

- [ ] **Step 3: Add precache lines to `custom_hero_portrait.css`** — **only for images that exist** (a missing source breaks the whole CSS compile). For each hero:
```css
.PrecacheImg_<name>_selection { background-image: url("file://{images}/heroes/selection/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_portrait  { background-image: url("file://{images}/heroes/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_icon      { background-image: url("file://{images}/heroes/icons/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_crop      { background-image: url("file://{images}/heroes/crops/npc_dota_hero_<name>.png"); }
```

- [ ] **Step 4: Final in-client check** — pick-screen portrait, top-bar image, and inspect portrait render for all three; no `Failed loading ..._png.vtex_c`. Commit:
```bash
git add content/dota_addons/dota2_meme_mode/panorama/
git commit -m "feat(custom-heroes): portraits for moosestache, occupational hazard, mr badhabits"
```

---

## Self-review notes (for the executor)

- **Spec coverage:** Phases 1–3 cover all three heroes' KV/abilities/talents/loc/toggle; Phase 5 covers every Scepter (native + tiny-Lua) and Shard; Phase 6 covers portraits. The spec's "verify, don't assume" list maps to Phase 4 (spawning/innates/Bone Guard/Toss) and Phase 5 Step 1 (facet caveat).
- **No new types/identifiers are referenced before they're defined** (modifier names match their `LinkLuaModifier` strings; hidden-ability names match the KV file and the hero `Ability4` wiring).
- **Two flagged adjustments** the user should see at handoff: (a) Moosestache Scepter is a Chronosphere **cooldown reduction**, not "allies act inside" (the latter wasn't tiny); (b) Occupational Hazard's Spirit Siphon Shard is a **damage-to-heal** conversion, not a literal self-cast (self-cast would mutate the shared stock ability). Both stay within the approved "tiny Lua, source-flavored, not overpowered" intent.
