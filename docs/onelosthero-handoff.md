# OneLostHero — Morning Handoff

Built overnight on branch `feat/onelosthero` (then merged to `main`). The hero, all five
abilities, the Echo/swap system, the ultimate, and Scepter are implemented in **Lua**
(the brief was written for TSTL/x-template, which this repo is not — see the spec at
`docs/superpowers/specs/2026-05-29-onelosthero-custom-hero-design.md`).

Everything below is what's left, and it's almost entirely **art + a play-test**, plus a
couple of small code rough-edges flagged at the end.

---

## ✅ Done (code-complete, untested in-game)

- Hero `npc_dota_hero_onelosthero` registered (Riki model/voice, BaseClass pattern, HeroID 251,
  agility), in `herolist.txt` + the Custom Heroes toggle.
- 5 KV ability files with every gameplay value from the brief; localization (name/bio + all
  ability + value tooltips) in `addon_english.txt`.
- Echo system (`scripts/vscripts/abilities/onelosthero/echo.lua`): create / expire / swap with
  full validity checks, fragile + non-farming dummy (`npc_onelosthero_echo`, Riki model).
- Innate Lost Signal, Q Second Stroke, W Blindspot Dagger, E False Hero, R Vanishing Point,
  Scepter (Many Lost, One Returned). Placeholder Valve particles/sounds throughout.
- Portrait: registered in `custom_hero_portrait.js` `CUSTOM_HEROES` (needs art — below).

---

## 🌅 Your morning tasks

### 1. PLAY-TEST FIRST (highest priority — unblocks everything)
Launch as a real custom game (Hammer does NOT run the addon Lua):
```
dota_launch_custom_game dota2_meme_mode dota
```
Enable the **Custom Heroes** toggle on the setup screen, pick OneLostHero, and run the
brief's Testing Checklist (innate → Q → W → E → R → Scepter). Watch the console for Lua
errors. **This is also the first real test of the Flasaro custom-hero pipeline**, which was
never verified in-game — if Flasaro doesn't spawn, OneLostHero won't either, and the fix
(per `docs/guides/creating-custom-heroes.md`) applies to both.

### 2. Custom model + animations  (the big art lift — can't be done in code)
The hero currently **uses Riki's model and animations** as a placeholder. For the locked
visual direction (dark rogue-duelist, sword + dagger, tattered cloak, glowing triskele,
blue-violet Echo energy) you need a custom `.vmdl`.

What's needed and where to start:
- **Model + textures**: a rigged humanoid wielding sword + dagger. Options, easiest → hardest:
  - *Reskin a Valve hero* (fastest): retexture Riki / Phantom Assassin / Ember Spirit in
    Source 2 (Blender → import the base `.vmdl`'s mesh, repaint, re-export). Keeps the
    existing skeleton + animations for free.
  - *Commission / buy*: ArtStation, Fiverr, or the SteamWorkshop modeller community; ask for
    a Dota-2-compatible character on a standard humanoid skeleton.
  - *Build from scratch*: Blender + the Source 2 Dota workshop tools (`Asset Browser` →
    `Model Editor`). Reference: Valve's "Dota 2 Workshop — Character Art Guide" and
    `developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools`.
- **Animations** the abilities call (must exist on the model's skeleton, or swap the activity
  in each KV `AbilityCastAnimation`):
  - `ACT_DOTA_CAST_ABILITY_1` (Q, Second Stroke — a forward sword slash reads best)
  - `ACT_DOTA_CAST_ABILITY_2` (W, Blindspot Dagger — a dagger throw/stab)
  - `ACT_DOTA_CAST_ABILITY_3` (E, False Hero — a "cast a clone" gesture)
  - `ACT_DOTA_CAST_ABILITY_4` (R, Vanishing Point — a vanish/crouch)
  - plus the standard `ACT_DOTA_IDLE`, `RUN`, `ATTACK1/2`, `DEATH`.
  - If you reuse a Valve skeleton, all of these come for free. Custom anims → FBX in Blender,
    imported via the Model Editor's animation list.
- **Install**: drop the compiled `.vmdl` under `content/.../models/heroes/onelosthero/` and
  point the hero's `"Model"` (in `npc_heroes_custom.txt`) + the Echo unit's `"Model"`
  (in `npc_units_custom.txt`) at it.

### 3. Portrait art  (small, but currently blank)
The portrait override is wired; it just needs PNGs. Ship these (any reasonable res, PNG):
```
content/.../panorama/images/heroes/npc_dota_hero_onelosthero.png            (top bar / loadout)
content/.../panorama/images/heroes/selection/npc_dota_hero_onelosthero.png  (pick-screen portrait)
content/.../panorama/images/heroes/icons/npc_dota_hero_onelosthero.png      (scoreboard)
content/.../panorama/images/heroes/crops/npc_dota_hero_onelosthero.png      (cropped)
```
A character splash / concept render works fine to start. (Same blank-portrait limitation
applies to Flasaro until its art ships.)

### 4. Custom particles + sounds  (polish)
Everything uses Valve placeholders (Void Spirit step, Riki backstab, Spectre desolate,
Terrorblade mirror/sunder, Nightstalker void, generic slow/silence). Replace with custom
blue-violet "Echo energy" `.vpcf` in the Particle Editor when you want the real look. The
ability icons (`AbilityTextureName`) also point at borrowed Valve icons — swap for custom art.

### 5. Balance pass
All numbers are the brief's first-draft values and live in the KV files
(`scripts/npc/abilities/onelosthero_*.txt`) — tune freely, no code changes needed.

---

## ⚠️ Code rough-edges to verify / finish

- **Recast-to-swap** (Q/W/E) uses an `EndCooldown` + mana-refund trick so the ability is
  re-castable during the swap window. Verify it feels right; if the engine re-applies cooldown
  oddly, the clean fix is a hidden sub-ability (the brief anticipated this).
- **W swap recast** ignores its target (W is unit-target). If that's awkward, move the swap to a
  sub-ability or auto-swap.
- **Shard (Unseen Exchange)** is gated by `HasShard()` but the *free-swap-during-ult →
  abandoned-Echo-detonation* path is a stub (`NotifyShardSwap` is never called, because swapping
  during the ult isn't wired to the ult yet). Scepter is fully implemented; Shard needs this last
  hookup. Search `vanishing_point.lua` for `NotifyShardSwap`.
- **Fear** issues move-orders away from the burst source every 0.1s and sets
  `MODIFIER_STATE_FEARED` + command-restricted. Confirm it's not too strong/long.
- The Echo dummy is `npc_dota_creature` with Riki model; killable clones (False Hero) take
  `clone_incoming_damage_pct` extra damage to stay fragile. Confirm they die fast enough and
  never give gold/XP.

---

## Files
- KV: `scripts/npc/abilities/onelosthero_*.txt`, `npc_heroes_custom.txt`, `npc_units_custom.txt`,
  `npc_abilities_custom.txt` (includes), `herolist.txt`
- Lua: `scripts/vscripts/abilities/onelosthero/{echo,lost_signal,second_stroke,blindspot_dagger,false_hero,vanishing_point}.lua`
- Plugin: `plugin_system/plugins/custom_heroes/plugin.lua`
- Loc: `resource/addon_english.txt`
- Portrait: `panorama/scripts/custom_game/custom_hero_portrait.js`
