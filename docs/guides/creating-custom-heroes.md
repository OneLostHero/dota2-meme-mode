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

There is **no pure-KV way** to give a *server-only* custom hero a client portrait on
the **pick screen** (pre-spawn, the client doesn't know the hero), so its grid card,
the big inspect portrait, and the top player row render blank. We fix the pick screen
with static PNGs. **In-game the engine renders the portrait natively from the hero's
model — do NOT touch the in-game HUD** (overlaying it covers the live portrait).

### 4a. Ship the four PNGs

```
content/.../panorama/images/heroes/npc_dota_hero_<name>.png            (top bar / loadout)
content/.../panorama/images/heroes/selection/npc_dota_hero_<name>.png  (pick-screen portrait)
content/.../panorama/images/heroes/icons/npc_dota_hero_<name>.png      (scoreboard icon)
content/.../panorama/images/heroes/crops/npc_dota_hero_<name>.png      (cropped)
```
**Aspect:** the selection/grid portrait slot is a **tall ~3:4 (vertical) portrait**. A
square source gets stretched tall — center-crop square art to 3:4 (e.g. 940×1254)
before shipping. The same image in all four slots is fine.

### 4b. Reference each PNG from the compiled CSS (so it COMPILES)

**CRITICAL — the PNGs must be COMPILED to `_png.vtex_c`, or the portrait is blank**
(engine logs `Failed loading .../selection/npc_dota_hero_<name>_png.vtex_c
(File not found)`). Addon panorama PNGs only compile when referenced by a **compiled
stylesheet/layout** — a JS-only `backgroundImage` reference is NOT enough. Add four
lines to `panorama/styles/custom_game/custom_hero_portrait.css` (included by
`custom_hero_portrait.xml`):

```css
.PrecacheImg_<name>_selection { background-image: url("file://{images}/heroes/selection/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_portrait  { background-image: url("file://{images}/heroes/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_icon      { background-image: url("file://{images}/heroes/icons/npc_dota_hero_<name>.png"); }
.PrecacheImg_<name>_crop      { background-image: url("file://{images}/heroes/crops/npc_dota_hero_<name>.png"); }
```
**Only reference images that exist** — a missing `url(...)` source breaks the whole
CSS compile (and every portrait with it).

### 4c. How the `.vtex_c` actually gets built (the step that bites)

The CSS reference is necessary but the compile happens in the **Dota 2 Workshop Tools
asset pipeline**, NOT from a plain game launch and NOT from the command line:

- `resourcecompiler.exe -i <file>.png` does **NOT** work — it reports
  `Failed to find compiler for file ".png"`. There is no standalone PNG compiler.
- The `_png.vtex_c` is produced by the **Workshop Tools asset watcher / on-demand
  recompiler** while running in tools/dev mode (the same system that hot-recompiles
  `.js`→`.vjs`). When you launch in tools mode and the pick screen requests the image,
  it compiles to `game/.../<path>/npc_dota_hero_<name>_png.vtex_c`.

So after adding a hero's PNGs + CSS lines: **launch in tools/dev mode and open the
hero pick screen once**, then verify the four files exist:
```
game/.../panorama/images/heroes/{,selection/,icons/,crops/}npc_dota_hero_<name>_png.vtex_c
```
If they're missing, the portrait will be blank in a normal launch. (These `.vtex_c`
are gitignored build artifacts — they are not committed; each machine compiles them.)

### 4d. Register the hero in the portrait script

`panorama/scripts/custom_game/custom_hero_portrait.js` (registered in
`custom_ui_manifest.xml` as **both** `type="HeroSelection"` and `type="Hud"`) patches
the pick-screen panels for any hero in its `CUSTOM_SHORT` table. **Use the SHORT hero
name** (no `npc_dota_hero_` prefix) — Panorama's `player_selected_hero` and panel
`.heroname` return the short form (`"flasaro"`, not `"npc_dota_hero_flasaro"`):

```js
var CUSTOM_SHORT = {
    "flasaro": true,
    "onelosthero": true,
    "<name>": true,   // add new heroes here, SHORT name
};
```

How the script works (so future edits don't re-break it):
- It runs **only during `HERO_SELECTION`/`STRATEGY_TIME`** (`Game.GetState()` gate) —
  never in-game, or it would cover the live native portrait.
- A `DOTAHeroImage`/`DOTAHeroMovie` paints its own (blank, for a custom hero) texture
  **over its child panels**, so the static image is laid as a **sibling on the panel's
  parent** (not a child), pixel-sized and positioned via `GetPositionWithinWindow()`.
- Percentage sizes on these overlays resolve to 0 — always size overlays in **pixels**.

Known limitation: the **minimap icon** is a rare unfixable. A 3D animated pick-screen
portrait would need the model resolvable client-side (see `scripts/npc/portraits.txt`,
keyed by model name) — out of scope for the static-image approach.

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
- [ ] Listed in `herolist.txt` (`"npc_dota_hero_<name>" "1"`).
- [ ] Precached in `addon_game_mode.lua`.
- [ ] Added to the `custom_heroes` list in `plugin_system/plugins/custom_heroes/plugin.lua`
      (full name). **Don't list a hero here that isn't fully defined** — a dangling
      `npc_dota_hero_*` with no KV/herolist/PNGs is a broken reference.
- [ ] **Portrait — all of these, or it's blank:**
  - [ ] Four PNGs shipped (`heroes/{,selection,icons,crops}/`), selection art ~3:4.
  - [ ] Four `.PrecacheImg_<name>_*` lines in `custom_hero_portrait.css`.
  - [ ] Short name added to `CUSTOM_SHORT` in `custom_hero_portrait.js`.
  - [ ] Compiled in tools/dev mode — verify the four `_png.vtex_c` exist under
        `game/.../panorama/images/heroes/...`.
- [ ] Localization tokens in `addon_english.txt`.
- [ ] Test via `dota_launch_custom_game dota2_meme_mode dota` (not Hammer — Hammer
      doesn't run the addon game-mode Lua).
