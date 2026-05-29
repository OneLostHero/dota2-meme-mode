# Creating a Custom Hero (Dota 2 — Meme Mode)

How to add a brand-new hero to the pool (not an override of an existing one), the
way Flasaro was added. Written for the current Dota client (build 6796+, post-facet
removal). Reference implementation: **Flasaro** (`npc_dota_hero_flasaro`).

> TL;DR of the hard-won lessons:
> - **`BaseClass` is mandatory** — without it the hero is pickable but never spawns
>   and its portrait is black.
> - Use a **high, unused `HeroID`** (e.g. 250), not a recycled low gap.
> - **Do NOT add a `Facets` block** — facets were removed from the game.
> - **Do NOT use `override_hero`** — it mutates the target hero (it broke Dragon Knight).
> - The hero must be in **`herolist.txt`** to appear in the pick grid.
> - The hero must be **precached**, or the client can't fully instantiate it.
> - The pick/top-bar **portrait is a Panorama-only fix** (static PNG override).

---

## 1. Define the hero — `game/.../scripts/npc/npc_heroes_custom.txt`

Add a KV block under `"DOTAHeroes"`. This file is auto-loaded by the engine.

```
"npc_dota_hero_flasaro"
{
    "BaseClass"             "npc_dota_hero_dragon_knight"  // REQUIRED. Inherits a real hero class so the hero spawns + renders. Does NOT override the base hero.
    "HeroID"                "250"                          // High, unused id. Recycled low gaps (e.g. 24) are pickable but won't spawn. Keep well under the engine max.
    "Enabled"               "1"
    "Team"                  "Good"
    "TeamName"              "DOTA_TEAM_GOODGUYS"
    "AttributePrimary"      "DOTA_ATTRIBUTE_STRENGTH"      // REQUIRED (hero-pool Lua does _G[attr]+1).

    // Look + voice (borrowed from the BaseClass hero here)
    "Model"                 "models/heroes/dragon_knight/dragon_knight.vmdl"
    "ModelScale"            "0.84"
    "SoundSet"              "Hero_DragonKnight"

    // Abilities (Q W E + hidden + ultimate, innate, then talents 10-17)
    "Ability1"              "antimage_blink"
    "Ability2"              "riki_blink_strike"
    "Ability3"              "sven_great_cleave"
    "Ability4"              "generic_hidden"
    "Ability5"              "generic_hidden"
    "Ability6"              "sven_gods_strength"
    "Ability7"              "sven_vanquisher"              // Innate (borrowed Sven innate)
    "Ability10"             "special_bonus_unique_sven_5"
    // ... Ability11-17 = the talent tree ...

    // Attributes + combat + classification (copy from the BaseClass hero; see Flasaro for the full set)
    "AttributeBaseStrength" "21"
    // ... AttackCapabilities, AttackDamageMin/Max, AttackRate, MovementSpeed, BoundsHullName,
    //     CombatClassAttack/Defend, UnitRelationshipClass, MovementCapabilities, etc. ...
}
```

Notes:
- **No `Facets` block.** Facets were removed; adding one does nothing useful and a
  working reference custom hero (`npc_dota_hero_aqua`) has none.
- **Don't set `AttackDamageType`** on the hero (it logs `Unknown Damage type`); heroes
  are physical by default.
- The model/voice can be any existing hero's. Custom models need their own `.vmdl`.

## 2. Show it in the pick grid — `scripts/npc/herolist.txt`

The pick grid (root key `CustomHeroList`) is a **whitelist**. If this file exists,
**only** the heroes listed in it appear — so it must list **every** hero you want
pickable, including all stock heroes AND your custom hero:

```
"CustomHeroList"
{
    "npc_dota_hero_antimage"   "1"
    ... every stock hero ...
    "npc_dota_hero_flasaro"    "1"
}
```

Omitting a hero hides it (this is how Largo/Ringmaster/Kez once vanished). When Valve
ships new heroes, add them here too.

## 3. Precache it — `scripts/vscripts/addon_game_mode.lua`

Vanilla heroes auto-precache on selection; custom ones do **not**. In `Precache(context)`:

```lua
local custom_heroes = LoadKeyValues('scripts/npc/npc_heroes_custom.txt')
if custom_heroes ~= nil then
    for hero_name, hero_data in pairs(custom_heroes) do
        if type(hero_data) == "table" then
            PrecacheUnitByNameSync(hero_name, context)
        end
    end
end
```

(With `BaseClass` set, the engine spawn path works; precache keeps assets ready.)

## 4. Portrait — Panorama static-image override

There is **no pure-KV way** to give a server-only custom hero a client portrait, so
the big pick-screen portrait and the in-game top-bar image render blank. Fix it in
Panorama by pointing those panels at static PNGs we ship.

Ship these images (any reasonable resolution; PNG):
```
content/.../panorama/images/heroes/npc_dota_hero_<name>.png            (top bar / loadout)
content/.../panorama/images/heroes/selection/npc_dota_hero_<name>.png  (pick-screen portrait)
content/.../panorama/images/heroes/icons/npc_dota_hero_<name>.png      (scoreboard icon)
content/.../panorama/images/heroes/crops/npc_dota_hero_<name>.png      (cropped)
```

Then the Hud script `panorama/scripts/custom_game/custom_hero_portrait.js`
(registered in `custom_ui_manifest.xml`) overrides the portrait for any hero listed
in its `CUSTOM_HEROES` table. To add a new custom hero, add its name there:

```js
var CUSTOM_HEROES = { "npc_dota_hero_flasaro": true, /* add new ones here */ };
```

Known limitation (per community): the **minimap icon** for a custom hero is a rare
unfixable. A 3D animated portrait would need a `.webm` movie panel (advanced).

## 5. Localization — `resource/addon_english.txt`

```
"npc_dota_hero_flasaro"             "Flasaro"
"npc_dota_hero_flasaro_bio"         "..."
"npc_dota_hero_flasaro_npedesc1"    "..."
```

Borrowed abilities/talents reuse their source hero's tooltips. If a talent shows a
raw `{s:bonus_x}` token, that talent's value/localization isn't resolving in this
context — usually cosmetic.

## 6. Optional: gate behind the Custom Heroes toggle

The `custom_heroes` plugin adds a setup-screen toggle (default off). It hides custom
heroes from the grid unless enabled, via per-player hero availability. Add new custom
heroes to its `custom_heroes` list (`scripts/vscripts/plugin_system/plugins/custom_heroes/plugin.lua`).

## Gotchas checklist

- [ ] `BaseClass` set to a real hero — **or it won't spawn / portrait is black**.
- [ ] `HeroID` high + unused (e.g. 250), `Enabled 1`, `AttributePrimary` set.
- [ ] No `Facets` block, no `override_hero`, no `AttackDamageType`.
- [ ] Listed in `herolist.txt`.
- [ ] Precached in `addon_game_mode.lua`.
- [ ] Portrait PNGs shipped + name added to `custom_hero_portrait.js`.
- [ ] Localization tokens in `addon_english.txt`.
- [ ] Test via `dota_launch_custom_game dota2_meme_mode dota` (not Hammer — Hammer
      doesn't run the addon game-mode Lua).
