# OneLostHero, The Last Signal — Implementation Spec (repo-adapted)

Date: 2026-05-29
Status: approved for autonomous overnight build (Phases 1–5)
Source brief: `OneLostHero Implementation Brief.pdf` (design-locked — do not redesign the kit)

## 0. Why this spec exists

The source brief was written for an **x-template / TSTL (TypeScript→Lua)** project. This
repo (`dota2-meme-mode`) is a **plain-Lua** custom game (MGMod fork). The hero *fantasy
and ability kit are locked by the brief*; this spec only re-targets the *implementation*
to this repo's actual conventions. Key translations:

| Brief (x-template) | This repo (Lua) |
|---|---|
| `game/scripts/src/abilities/**/*.ts`, `dota_ts_adapter`, `@registerAbility` | `scripts/vscripts/abilities/**/*.lua`, global `name = class({})` |
| `@registerModifier` | `LinkLuaModifier("modifier_x", "<scriptpath>", LUA_MODIFIER_MOTION_NONE)` + `class({})` |
| `npx gulp kv_2_js` / `jssync` compile step | **none** — engine reads KV directly in Lua mode |
| Localization in `game/resource/addon.csv` | `resource/addon_english.txt` (KV format) |
| Hero entry `"override_hero" "npc_dota_hero_riki"` | **FORBIDDEN here** — use the Flasaro `BaseClass` custom-hero pattern |
| `this.GetSpecialValueFor("x")` | `self:GetSpecialValueFor("x")` (identical engine API) |

`GetSpecialValueFor`, `ApplyDamage`, `FindClearSpaceForUnit`, `CreateUnitByName`,
`AddNewModifier`, `HasShard()/HasScepter()` are all the same engine API — only the language
wrapper differs.

## 1. Decisions (locked with user, 2026-05-29)

- **Model / BaseClass:** Riki (`npc_dota_hero_riki`, `models/heroes/rikimaru/rikimaru.vmdl`, `Hero_Riki`).
- **Registration:** full standalone custom hero now (Flasaro pattern), `HeroID 251`.
- **Scope tonight:** full prototype, Phases 1–5 (innate, Q, W, E, R, Shard, Scepter).
- **Attribute:** Agility (assassin), matching Riki.
- **Out of scope (morning tasks):** custom model, rigging/animations, final custom
  particles/sounds, in-game play-test + balance, portrait art + panorama wiring.

## 2. Hero registration (Flasaro pattern — see docs/guides/creating-custom-heroes.md)

`scripts/npc/npc_heroes_custom.txt` — add a second hero in the `"DOTAHeroes"` block:

- `BaseClass npc_dota_hero_riki` (REQUIRED — spawns + renders), `HeroID 251`, `Enabled 1`,
  `Team Good`, `TeamName DOTA_TEAM_GOODGUYS`, `AttributePrimary DOTA_ATTRIBUTE_AGILITY`.
- Riki model / `ModelScale 0.87` / `SoundSet Hero_Riki` / Riki base stats.
- `Ability1` `onelosthero_second_stroke` (Q), `Ability2` `onelosthero_blindspot_dagger` (W),
  `Ability3` `onelosthero_false_hero` (E), `Ability4`/`Ability5` `generic_hidden`,
  `Ability6` `onelosthero_vanishing_point` (R), `Ability7` `onelosthero_lost_signal` (innate).
- **No `Facets`, no `override_hero`, no `AttackDamageType` on the hero.**
- `herolist.txt`: add `"npc_dota_hero_onelosthero" "1"`.
- `plugin_system/plugins/custom_heroes/plugin.lua`: append to `custom_heroes` list (gated
  behind the Custom Heroes toggle, same as Flasaro).
- Precache: already generic in `addon_game_mode.lua` (loops `npc_heroes_custom.txt`) — no edit.
- **Portrait: deferred to morning** (panorama manifest is fragile + needs art). Hero spawns
  & plays with a blank portrait, exactly like Flasaro currently.

## 3. KV ability files (`scripts/npc/abilities/onelosthero_*.txt`)

Five files, each `BaseClass ability_lua`, `ScriptFile "abilities/onelosthero/<name>"`,
`AbilityTextureName` placeholder (a stock icon), values copied verbatim from the brief's
`AbilityValues` blocks. Add five `#base` includes to `npc_abilities_custom.txt` (after the
existing static includes, before/clear of the generated per-hero block).

Values per brief (authoritative — do not change):
- lost_signal: trigger_window 3.0, bonus_damage 35, echo_damage_pct 35, echo_duration 1.5, internal_cooldown 6.0
- second_stroke: slash_distance 450/500/550/600, slash_width 140, damage 80/130/180/230, echo_delay 0.35, echo_damage_pct 40/50/60/70, echo_duration 2.5, swap_window 2.5, dash_speed 1800
- blindspot_dagger: dagger_damage 60/100/140/180, mark_duration 4.0, slow_pct -18/-22/-26/-30, echo_strike_damage 40/70/100/130, silence_duration 0.8/1.1/1.4/1.7, backstab_angle 110, echo_duration 2.0, swap_window 2.0
- false_hero: clone_distance 550/650/750/850, clone_duration 3.0/3.5/4.0/4.5, clone_movespeed_pct 100, clone_incoming_damage_pct 250, burst_radius 300, burst_slow_pct -25/-30/-35/-40, burst_slow_duration 2.0, disarm_duration 0.8/1.0/1.2/1.4, swap_window 4.5
- vanishing_point: charge_duration 2.5/3.0/3.5, movespeed_bonus_pct 20/25/30, release_radius 475, base_damage 180/280/380, max_charge_bonus_pct 50, fear_duration 1.1/1.4/1.7, echo_burst_damage_pct 35, warning_radius 275, warning_delay 1.0, swap_allowed 1, shard_free_swap 1, shard_warning_suppression 0.75, shard_echo_detonation_pct 45, scepter_extra_echoes 2, scepter_echo_spread_distance 500, scepter_echo_burst_damage_pct 45, scepter_echo_fear_pct 60

## 4. Lua ability files (`scripts/vscripts/abilities/onelosthero/`)

`echo.lua` — shared module (NOT an ability). Plain Lua table `OneLostHeroEcho` returned via
`require`, plus a `LinkLuaModifier`'d `modifier_onelosthero_echo` that makes a dummy fragile,
non-farming, short-lived, and visually an afterimage. Functions:
- `CreateEcho(owner, ability, origin, opts)` → dummy via `CreateUnitByName` (Riki model),
  applies the echo modifier with `duration`, `incoming_damage_pct`, `canSwap`, `sourceAbility`.
- `ExpireEcho(echo)` — clean destroy + particle.
- `SwapWithEcho(caster, echo)` — validity checklist (caster/echo alive & non-null, not expired,
  caster not stunned/rooted/hexed/command-restricted via `IsStunned/IsRooted/IsHexed/IsCommandRestricted`,
  destination valid) → `FindClearSpaceForUnit` both, placeholder particle/sound.
- `FindUnitsInLine(...)` wrapper, `IsBehindOrSide(attacker, target, angleDeg)` for W.

Each ability file = its ability `class({})` + its ability-owned modifiers (brief's modifier
names) declared via `LinkLuaModifier` at top. Behavior exactly per brief's per-ability "Behavior"
+ "Acceptance Criteria" sections. All numbers via `GetSpecialValueFor`. Recast/swap: track an
`activeEcho` + `swapUntil` on the ability instance; while a swap window is open the ability is
re-castable (toggle behavior via `GetBehavior`/auto-cast or a hidden state flag) to trigger swap.

R (vanishing_point) charge damage:
`final = base_damage * (1 + clamp(elapsed/charge_duration,0,1) * max_charge_bonus_pct/100)`.
Fear = custom `modifier_onelosthero_vanishing_point_fear`: command-restricted + periodic
move orders away from burst source via `OnIntervalThink`, debuff, removed after `fear_duration`.
Shard/Scepter gated strictly by `caster:HasShard()` / `caster:HasScepter()`.

## 5. Localization (`resource/addon_english.txt`)

Hero name/bio/npedesc + every ability name/description + every `AbilityValues` key tooltip
(the brief lists all tokens verbatim; reuse them as `DOTA_Tooltip_ability_onelosthero_*`).

## 6. Build order / commits (per brief's git plan, adapted)

1. KV ability files + `#base` includes + localization stubs.
2. Lua ability skeletons (classes + modifier registrations) — loads clean.
3. `echo.lua`: Echo create/expire/swap helpers + echo modifier.
4. Second Stroke (Q) + False Hero (E).
5. Blindspot Dagger (W).
6. Vanishing Point (R): invis charge, burst, fear, echo bursts.
7. Shard + Scepter for R.
8. Hero registration (KV entry, herolist, custom_heroes plugin) + spec/guide/memory updates.

Each commit ff-merges to `main` per the repo's ship-to-main workflow.

## 7. Definition of done (this build)

- Hero `npc_dota_hero_onelosthero` registered (Flasaro pattern), appears in herolist, gated
  behind Custom Heroes toggle.
- All 5 abilities exist in KV + Lua, load without Lua/KV errors, tooltips present.
- Echo create/expire/swap works; Q/W/E/R behavior matches brief acceptance criteria.
- Shard/Scepter gated by HasShard()/HasScepter().
- No hardcoded gameplay constants in Lua.
- Morning-task list handed to user (model, anim, particles, portrait, in-game test/balance).

## 8. Risks / caveats

- The Flasaro custom-hero pipeline is **documented but UNVERIFIED in-game** (user play-tests it
  "in the morning"). OneLostHero inherits that risk: if Flasaro doesn't spawn, OneLostHero won't
  either, and the fix applies to both.
- Recast-to-swap on a non-toggle ability needs care; prototype may use a short auto-recast window
  or a sub-ability. Documented as a known-rough edge per the brief.
- Portrait will be blank until the morning panorama/art task.
