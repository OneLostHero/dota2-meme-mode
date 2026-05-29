# Moosestache, Occupational Hazard & Mr. BadHabits — Custom Hero Design

Three new "Frankenstein" custom heroes assembled almost entirely from existing Valve
abilities, following the proven Flasaro / OneLostHero pipeline documented in
`docs/guides/creating-custom-heroes.md`.

- **Build approach:** KV-only borrowed abilities, with a *small, surgical* amount of
  Lua permitted **only** for the few Aghs/Shard effects that cannot fire natively from a
  borrowed ability's own KV (decided during brainstorming).
- **Aghs philosophy:** Scepter upgrades the ultimate; Shard upgrades a basic ability.
  Talents/Aghs/Shard are a **balanced hybrid** — source-flavored but tuned for these
  specific 4-ability kits, not copied verbatim.
- **HeroIDs:** Moosestache `252`, Occupational Hazard `253`, Mr. BadHabits `254`
  (Flasaro is 250, OneLostHero is 251 — keep climbing, never recycle low gaps).

> Internal ability names below are best-known and **must be verified against the live
> game files at implementation** (the guide's standard caveat). Borrowed innates/abilities
> that reference hero-specific mechanics may need a substitute — verify each spawns and
> behaves on the new carrier hero.

---

## Hero 1 — Moosestache

**Fantasy:** a momentum bruiser-carry. Charge across the map, tether to leech a victim's
attack damage, lock the teamfight in a time bubble, and crit with stolen power.

- **Model / voice / stats base:** Bloodseeker (`models/heroes/bloodseeker/bloodseeker.vmdl`,
  `Hero_Bloodseeker`).
- **BaseClass:** `npc_dota_hero_bloodseeker` (real class so it spawns + renders; Bloodseeker untouched).
- **Primary attribute:** Agility. Copy Bloodseeker's attributes/combat/classification block.
- **Roles:** Carry, Initiator, Disabler, Durable. Complexity 2.

### Abilities

| Slot | Ability | Source | Internal name (verify) | Type |
|---|---|---|---|---|
| Q (Ability1) | Charge of Darkness | Spirit Breaker | `spirit_breaker_charge_of_darkness` | active, global wind-up charge |
| W (Ability2) | Static Link | Razor | `razor_static_link` | active, tether steals attack damage |
| E (Ability3) | Jinada | Bounty Hunter | `bounty_hunter_jinada` | passive, bonus-damage strike on cd |
| Ability4/5 | `generic_hidden` | — | — | — |
| R (Ability6) | Chronosphere | Faceless Void | `faceless_void_chronosphere` | ultimate |
| Innate (Ability7) | Distortion Field | Faceless Void | `faceless_void_distortion_field` | passive projectile-slow aura |

### Talent tree (real stock tokens — verified functional, pre-balanced)

A borrowed talent only does something if the held ability's KV references that token, so
the tree uses **real source-hero tokens that hook a held ability**, plus generic stat
tokens. (Chronosphere has **no** talent hooks in this build, so the ult carries itself and
talents focus on the basics.) Stock tokens also bring their own localization for free.

| Lvl | Left (token) | Right (token) |
|---|---|---|
| 10 | Jinada — `special_bonus_unique_bounty_hunter` | +Move Speed — `special_bonus_movement_speed_30` |
| 15 | Static Link AS — `special_bonus_unique_razor_static_link_aspd` | Charge of Darkness — `special_bonus_unique_spirit_breaker_4` |
| 20 | Jinada — `special_bonus_unique_bounty_hunter_4` | +Attack Damage — `special_bonus_attack_damage_40` |
| 25 | Jinada no cooldown — `special_bonus_unique_bounty_hunter_jinada_no_cooldown` | Static Link — `special_bonus_unique_razor` |

### Aghanim's — Scepter on the ultimate (Chronosphere)

- **Effect:** allied heroes can move & attack inside the Chronosphere, and −30s cooldown.
- **Feasibility:** **NOT native** to `faceless_void_chronosphere` (FV's real Scepter lives
  on Time Walk). Requires **a few lines of Lua** — a small modifier/think that lets allied
  units act inside the sphere when the caster has a Scepter, plus a KV scepter cooldown
  value. This is the sanctioned "tiny Lua" case.

### Aghanim's — Shard on a basic ability (Charge of Darkness)

- **Effect:** −cooldown and bonus magic resistance while charging.
- **Feasibility:** prefer the ability's own shard special values if present; otherwise a
  small modifier applied on the charge modifier. Verified at planning.

---

## Hero 2 — Occupational Hazard

**Fantasy:** a necro-caster / summoner / drain attritionist. Melt the enemy with an aura,
raise skeletons, siphon their life, and finger the survivor.

- **Model / voice / stats base:** Necrophos (`models/heroes/necrolyte/necrolyte.vmdl`,
  `Hero_Necrolyte`).
- **BaseClass:** `npc_dota_hero_necrolyte` (real class so it spawns + renders; Necrophos untouched).
- **Primary attribute:** Intelligence. Copy Necrophos's attributes/combat/classification block.
- **Roles:** Nuker, Disabler, Pusher, Durable. Complexity 2.

### Abilities

| Slot | Ability | Source | Internal name (verify) | Type |
|---|---|---|---|---|
| Q (Ability1) | Spirit Siphon | Death Prophet | `death_prophet_spirit_siphon` | active, HP-drain tether, charges |
| W (Ability2) | Bone Guard | Wraith King | `skeleton_king_bone_guard` | active, charge-based skeleton summon |
| E (Ability3) | Heart Stopper Aura | Necrophos | `necrolyte_heartstopper_aura` | passive aura, %max-HP/s |
| Ability4/5 | `generic_hidden` | — | — | — |
| R (Ability6) | Finger of Death | Lion | `lion_finger_of_death` | ultimate, execute nuke + kill stacks |
| Innate (Ability7) | Storm Surge | Razor | `razor_storm_surge` | passive MS + lightning proc |

> **Bone Guard note:** WK's Bone Guard gains charges from kills and summons skeletons that
> benefit from Vampiric Spirit / Wraithfire-Blast targeting on WK. On Occupational Hazard
> those WK-specific hooks won't exist; the core summon should still work, but verify the
> skeletons spawn, are uncontrollable-but-aggressive, expire/respawn correctly, and don't
> error from missing WK modifiers. If it misbehaves, fall back to a cleaner summon source.

### Talent tree (real stock tokens — verified functional, pre-balanced)

Bone Guard has **no** talent hooks in this build, so talents focus on Heart Stopper,
Spirit Siphon, the Storm Surge innate, and Finger of Death, plus a stat.

| Lvl | Left (token) | Right (token) |
|---|---|---|
| 10 | Heart Stopper — `special_bonus_unique_necrophos_2` | Spirit Siphon — `special_bonus_unique_death_prophet_5` |
| 15 | Heart Stopper — `special_bonus_unique_necrophos_5` | Spirit Siphon — `special_bonus_unique_death_prophet_3` |
| 20 | Storm Surge (innate) — `special_bonus_unique_razor_storm_surge_damage_and_slow` | +Health — `special_bonus_health_250` |
| 25 | Finger of Death — `special_bonus_unique_lion_8` | +Magic Resist — `special_bonus_magic_resistance_10` |

### Aghanim's — Scepter on the ultimate (Finger of Death)

- **Effect:** Lion's native Finger of Death Scepter (reduced cooldown, increased damage).
- **Feasibility:** **NATIVE — pure KV-only ✓.** `lion_finger_of_death` reads
  `HasScepter()` internally, so simply owning the ability + a Scepter applies the upgrade.
  No Lua needed. This is the clean reference case.

### Aghanim's — Shard on a basic ability (Spirit Siphon)

- **Effect:** +1 Spirit Siphon charge and may target self to convert the drain into a
  heal/shield.
- **Feasibility:** the +charge half may be KV; the self-cast heal likely needs **a few
  lines of Lua**. Sanctioned "tiny Lua" case. Verified at planning.

---

## Hero 3 — Mr. BadHabits

**Fantasy:** a tanky, annoying punisher-thief. Toss the enemy around, bleed them with
stacking quills behind a meat shield, and steal their best spell.

- **Model / voice / stats base:** Treant Protector (`models/heroes/treant/treant.vmdl`,
  `Hero_Treant`).
- **BaseClass:** `npc_dota_hero_treant` (real class so it spawns + renders; Treant untouched).
- **Primary attribute:** Strength. Copy Treant Protector's attributes/combat/classification block.
- **Roles:** Durable, Disabler, Initiator, Nuker. Complexity 2.

### Abilities

| Slot | Ability | Source | Internal name (verify) | Type |
|---|---|---|---|---|
| Q (Ability1) | Toss | Tiny | `tiny_toss` | active, grab + throw a unit |
| W (Ability2) | Quill Spray | Bristleback | `bristleback_quill_spray` | active, stacking nuke |
| E (Ability3) | Meat Shield | Pudge | `pudge_flesh_heap` | active, self damage-block (8/14/20/26, 5–8s) |
| Ability4/5 | `generic_hidden` | — | — | — |
| R (Ability6) | Spell Steal | Rubick | `rubick_spell_steal` | ultimate |
| Innate (Ability7) | Flesh Heap | Pudge | `pudge_innate_graft_flesh` | passive, +STR on nearby hero kills/deaths |

> **Name mapping (verified against the on-disk stock dump):** in this build the
> damage-block "Meat Shield" active is internally `pudge_flesh_heap`
> (`damage_block` 8/14/20/26, duration 5–8s, cd 20–17s), and the strength-on-kills
> "Flesh Heap" innate is internally `pudge_innate_graft_flesh`. (Valve's display vs.
> internal names are swapped from intuition.)
>
> **Notes for verification:** Toss grabs the nearest unit around the caster and throws it —
> confirm it works without Tiny's other abilities. Quill Spray's stacking `quill_stack`
> debuff should carry over fine. `pudge_innate_graft_flesh` has
> `DependentOnAbility pudge_dismember`, which this hero lacks, so the innate will sit at
> base level (acceptable: it still grants STR, just at the lowest tier — do **not** override
> the stock ability to re-level it, as that would mutate Pudge in meme mode).

### Talent tree (real stock tokens — verified functional, pre-balanced)

Spell Steal has **no** generic talent hook in this build (only a removed-facet token), so
talents focus on Quill Spray, Toss, Meat Shield, plus tanky stats fitting Treant.

| Lvl | Left (token) | Right (token) |
|---|---|---|
| 10 | Quill Spray — `special_bonus_unique_bristleback_2` | +Health — `special_bonus_health_250` |
| 15 | Toss — `special_bonus_unique_tiny_2` | Meat Shield block ×1.5 — `special_bonus_unique_pudge_1` |
| 20 | Toss — `special_bonus_unique_tiny_5` | +Strength — `special_bonus_strength_12` |
| 25 | +Status Resist — `special_bonus_status_resistance_10` | +Attack Damage — `special_bonus_attack_damage_60` |

### Aghanim's — Scepter on the ultimate (Spell Steal)

- **Effect:** Rubick's native Spell Steal Scepter — reduced cooldown, increased cast range,
  and stolen abilities arrive already Aghs-upgraded.
- **Feasibility:** **NATIVE — pure KV-only ✓.** `rubick_spell_steal` reads the caster's
  Scepter internally; owning the ability + a Scepter applies the upgrade. No Lua needed.
  Second clean reference case alongside Finger of Death.

### Aghanim's — Shard on a basic ability (Meat Shield)

- **Effect:** +Meat Shield duration and reflects 25% of blocked damage as magic damage to
  nearby enemies (Pudge-flavored "bad habits punish you"; deliberately low power).
- **Feasibility:** the +duration is KV; the reflect needs **a few lines of Lua** on the
  Meat Shield modifier. Sanctioned "tiny Lua" case. Verified at planning.

---

## Shared implementation checklist (per the custom-hero guide)

For **each** hero:

1. **`npc_heroes_custom.txt`** — add the `DOTAHeroes` block (BaseClass, HeroID, Enabled,
   Team, AttributePrimary, Model/Scale/SoundSet, the 7 ability slots + talents 10–17, and
   the full attributes/combat/classification block copied from the base hero).
2. **`herolist.txt`** — add `"npc_dota_hero_moosestache" "1"`,
   `"npc_dota_hero_occupational_hazard" "1"`, and `"npc_dota_hero_mr_badhabits" "1"`
   (whitelist — must list every pickable hero).
3. **`addon_game_mode.lua` Precache** — already loops all entries of
   `npc_heroes_custom.txt`; new heroes are picked up automatically (verify).
4. **Portrait** — ship the 4 PNGs per hero (top-bar, selection, icons, crops), add the
   `.PrecacheImg_*` lines to `custom_hero_portrait.css`, and register both hero names in
   `custom_hero_portrait.js` `CUSTOM_HEROES`. (Art can be placeholder splash to start;
   blank-portrait limitation applies until shipped.)
5. **Localization** — `addon_english.txt`: hero name + `_bio` for each; borrowed abilities
   reuse their source tooltips. Add tokens for any new talent/Aghs values that show raw.
6. **Custom Heroes toggle** — add both hero names to the `custom_heroes` plugin list
   (`plugin_system/plugins/custom_heroes/plugin.lua`).
7. **Tiny-Lua effects** — only where flagged: Moosestache Chronosphere-Scepter (allies act
   inside), Occupational Hazard Spirit-Siphon-Shard self-heal. Place under
   `scripts/vscripts/abilities/<hero>/` and wire via `npc_abilities_custom.txt` overrides
   or modifier attach, following the OneLostHero Lua layout.

## Open items to resolve during planning (verify, don't assume)

- Exact internal names for every borrowed ability **and the three innates**
  (`faceless_void_distortion_field`, `razor_storm_surge`, `pudge_flesh_heap`) against live files.
- Whether borrowed **innates** spawn correctly on the new carrier (Distortion Field aura,
  Storm Surge proc, Flesh Heap STR-on-kill) without their home hero's other abilities — in
  particular Flesh Heap normally levels with Dismember, so pin a fixed level/value.
- Bone Guard skeleton behavior on a non-WK carrier (summon/expire/aggro, no missing-modifier errors).
- Toss behavior on a non-Tiny carrier (grabs + throws nearest unit correctly).
- Talent tokens are now locked to real stock tokens (verified each is referenced by a held
  ability's KV). Confirm in-client that each still resolves a value + tooltip; swap any
  generic stat token whose exact name differs in-build for the nearest existing one.
- **Aghs facet caveat:** some ult Scepter upgrades migrated to facets, which are removed in
  this mode. Verify in-client that **Finger of Death** and **Spell Steal** actually upgrade
  when the hero holds a Scepter (Spell Steal's is code-driven via `HasScepter`, so it should
  fire; Finger of Death references both `special_bonus_scepter` and a
  `facet_lion_fist_of_death` token — confirm the scepter path, not the facet path, triggers).
  If an ult's Scepter is facet-gated and dead, fall back to the sanctioned tiny-Lua numeric
  Scepter for that ult.
- Minimum-viable Lua surface for the non-native Aghs effects (Chronosphere allies-act,
  Meat Shield reflect, Spirit Siphon self-heal — keep each tiny).

## Gotchas (from the guide — apply to both)

- `BaseClass` mandatory, high unused HeroID, **no** `Facets` block, **no** `override_hero`,
  **no** `AttackDamageType` on the hero.
- Test only via `dota_launch_custom_game dota2_meme_mode dota` (Hammer doesn't run the
  addon Lua). This is still the first real in-game test of the whole custom-hero pipeline.
- Only reference portrait images that actually exist — a missing `url(...)` source breaks
  the entire CSS compile and kills all custom UI.
