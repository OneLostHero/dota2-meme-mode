# Moosestache & Occupational Hazard — Custom Hero Design

Two new "Frankenstein" custom heroes assembled almost entirely from existing Valve
abilities, following the proven Flasaro / OneLostHero pipeline documented in
`docs/guides/creating-custom-heroes.md`.

- **Build approach:** KV-only borrowed abilities, with a *small, surgical* amount of
  Lua permitted **only** for the few Aghs/Shard effects that cannot fire natively from a
  borrowed ability's own KV (decided during brainstorming).
- **Aghs philosophy:** Scepter upgrades the ultimate; Shard upgrades a basic ability.
  Talents/Aghs/Shard are a **balanced hybrid** — source-flavored but tuned for these
  specific 4-ability kits, not copied verbatim.
- **HeroIDs:** Moosestache `252`, Occupational Hazard `253` (Flasaro is 250,
  OneLostHero is 251 — keep climbing, never recycle low gaps).

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
| W (Ability2) | Static Link | Razor | `razor_link` | active, tether steals attack damage |
| E (Ability3) | Jinada | Bounty Hunter | `bounty_hunter_jinada` | passive, bonus-damage strike on cd |
| Ability4/5 | `generic_hidden` | — | — | — |
| R (Ability6) | Chronosphere | Faceless Void | `faceless_void_chronosphere` | ultimate |
| Innate (Ability7) | Distortion Field | Faceless Void | `faceless_void_distortion_field` | passive projectile-slow aura |

### Talent tree (balanced-hybrid, drawn from SB / Razor / BH / FV)

| Lvl | Left | Right |
|---|---|---|
| 10 | +25 Movement Speed | +40 Jinada bonus damage |
| 15 | −4s Charge of Darkness cooldown | +25% Static Link damage steal |
| 20 | +1.5s Chronosphere duration | Jinada: no cooldown (procs every attack) |
| 25 | +1 Static Link target | Charge of Darkness: +100 impact damage & +0.6s stun |

Where a stock talent token from the source hero matches (e.g. an existing
`special_bonus_unique_bounty_hunter_*` for Jinada no-cooldown, an FV Chronosphere-duration
token), reuse it. Otherwise use a generic `special_bonus_*` token with matching values.
Final token IDs resolved at planning against the live files.

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

### Talent tree (balanced-hybrid, drawn from Necro / Lion / DP / WK)

| Lvl | Left | Right |
|---|---|---|
| 10 | +1.5% max-HP/s Heart Stopper Aura | +1 Spirit Siphon charge |
| 15 | +250 Heart Stopper Aura radius | +2 Bone Guard skeletons |
| 20 | +2s Spirit Siphon duration & +40 dps | −20 Bone Guard charges required |
| 25 | +100 Finger of Death damage per kill | Spirit Siphon also heals you for amount drained |

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

## Shared implementation checklist (per the custom-hero guide)

For **each** hero:

1. **`npc_heroes_custom.txt`** — add the `DOTAHeroes` block (BaseClass, HeroID, Enabled,
   Team, AttributePrimary, Model/Scale/SoundSet, the 7 ability slots + talents 10–17, and
   the full attributes/combat/classification block copied from the base hero).
2. **`herolist.txt`** — add `"npc_dota_hero_moosestache" "1"` and
   `"npc_dota_hero_occupational_hazard" "1"` (whitelist — must list every pickable hero).
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

- Exact internal names for every borrowed ability **and the two innates**
  (`faceless_void_distortion_field`, `razor_storm_surge`) against live files.
- Whether borrowed **innates** spawn correctly on the new carrier (Distortion Field aura,
  Storm Surge proc) without their home hero's other abilities.
- Bone Guard skeleton behavior on a non-WK carrier (summon/expire/aggro, no missing-modifier errors).
- Which stock `special_bonus_*` talent tokens exist for the intended effects vs. needing a
  generic token + localized value.
- Minimum-viable Lua surface for the two non-native Aghs effects (keep it tiny).

## Gotchas (from the guide — apply to both)

- `BaseClass` mandatory, high unused HeroID, **no** `Facets` block, **no** `override_hero`,
  **no** `AttackDamageType` on the hero.
- Test only via `dota_launch_custom_game dota2_meme_mode dota` (Hammer doesn't run the
  addon Lua). This is still the first real in-game test of the whole custom-hero pipeline.
- Only reference portrait images that actually exist — a missing `url(...)` source breaks
  the entire CSS compile and kills all custom UI.
