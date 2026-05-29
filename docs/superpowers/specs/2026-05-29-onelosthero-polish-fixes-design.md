# OneLostHero — Polish Fixes (round 5)

Date: 2026-05-29
Status: approved (plan), implementing
Context: Kez-based custom hero in a **Legends of Dota** mod. Several mechanics not working
in-game despite prior commits (user rebuilds every test, so failures are real, not stale).

## Fixes

### 1. Second Stroke (Q)
- **Animation**: play Kez's Echo Slash on cast via `caster:StartGesture(ACT_DOTA_CAST_ABILITY_1)`
  (slot 1 = Kez's first-ability cast). Keep `AbilityCastAnimation ACT_DOTA_CAST_ABILITY_1`.
- **Visible slash**: spawn a sweeping blade line particle from start→end for the hero's slash
  AND the echo's repeat, so the line damage is readable even with no enemies.
- **Swap deals damage** (user choice = "slash toward old spot"): on the swap recast, after
  teleporting the hero to the echo's position, fire a reduced-damage line slash FROM the echo's
  position TOWARD the hero's pre-swap position (reverse direction), `slash_width`, damage =
  `damage * echo_damage_pct/100`. No-swap behavior (echo dashes forward + repeats) stays.

### 2. Innate — Lost Signal
- Root cause: arms on `ON_BREAK_INVISIBILITY`, which does NOT fire when our custom Lua invis
  modifier is removed → never arms.
- Fix: the intrinsic modifier polls via `StartIntervalThink(0.1)`, tracks `wasInvisible`; on an
  invisible→visible transition it arms (`readyUntil = now + trigger_window`). Works for any invis
  source (False Hero, future items). Keep `ON_ATTACK_LANDED` to consume → bonus damage + echo.
- Verify the intrinsic modifier applies on an innate ability (it should via
  `GetIntrinsicModifierName`); if the think isn't running, apply on `OnCreated`.

### 3. False Hero — clone forward movement
- Root cause: a one-shot attack-move order on a fresh illusion is dropped/reverts to idle.
- Fix: the echo's tracking modifier re-issues the forward attack-move toward a far waypoint
  every ~0.5s via `OnIntervalThink`, but only when the unit is idle (no current order /
  `IsIdle()` heuristic via `GetCurrentActiveAbility`/anim state) so it still auto-attacks.
  Store the forward dest on the unit (`unit.olh_echo.moveDest`). Applies only to the False Hero
  echo (flag the modifier, e.g. `drive_forward`), not Q/W/ult echoes.

### 4. Vanishing Point — animation + fear
- **Animation**: add `caster:StartGesture(ACT_DOTA_CAST_ABILITY_4)` on cast (Raptor Dance),
  in addition to the 0.4 cast point. (Belt-and-suspenders; gesture forces it even if the
  cast-point animation is skipped.)
- **Fear**: rework `modifier_onelosthero_vanishing_point_fear` to: command-restricted + a
  visible overhead fear particle (`generic_fear` or terrorblade) + `OnIntervalThink(0.1)`
  issuing move-away orders from the stored source. Drop reliance on `MODIFIER_STATE_FEARED`
  alone. Keep the talent pierce (non-purgable when piercing).

### 5. Talent tree (LoD)
- Still broken on latest build → custom talents not registering. This is an LoD mod; LoD only
  registers custom abilities with a `"CustomList"` key (plugin.lua PrepStageTwo line 184), and
  the tree may be engine-or-LoD driven.
- This round:
  1. **Diagnostics**: on hero spawn, print the hero's ability names at indices 0..23
     (so we see whether slots 10-17 hold the custom talents or got replaced). Gate behind a
     simple server print so the user can copy the console line.
  2. **Best-guess fix**: add `"AbilityValues" { "value" "1" }` and `"CustomList" "onelosthero"`
     to each custom talent (match the mod's custom-ability tagging); add the same `CustomList`
     to the hero's Q/W/E/R/ult/innate so LoD recognizes the set.
- User retests, shares the console output; definitive fix follows from that.

## Out of scope
- Custom model parts (Kez head/weapons), custom particles/sounds, balance.

## Risk / verification
- No local Lua runtime: changes pass structural checks only. The talent tree is explicitly
  diagnostic-first this round. Kez activity names (Echo Slash / Raptor Dance) are best-effort
  via the ACT_DOTA_CAST_ABILITY_n slots on the Kez model.
