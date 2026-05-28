# Dota 2 - Meme Mode

A modular Dota 2 sandbox where you bend the rules and turn the game into experiences
we have yet to try. Every feature is a self-contained, toggleable "plugin" — if a
plugin is left disabled it cleans itself up (UI included) and the game stays as close
to normal Dota 2 as possible.

Created by **OneLostHero**.

> Inspired by **MGMod** by DrTeaSpoon. Meme Mode is a remake that builds on that
> foundation. Huge respect and credit to the original project.

## Plugin System
The core of Meme Mode. Each module is a plugin that can be enabled or disabled at the
custom game setup screen.
More info: `game/dota_addons/dota2_meme_mode/scripts/vscripts/plugin_system/Readme.md`

## Per-Hero Ability Editing
Every active hero has its own folder of editable, **self-documenting** ability values:

```
game/dota_addons/dota2_meme_mode/scripts/npc/heroes/<hero>/abilities.txt
```

Each file is a full copy of that hero's abilities, annotated with:
- the ability's display name and icon reference,
- a hint on every value showing whether higher or lower is stronger.

Edit a number, save, relaunch — the change takes effect. The files are generated and
can be regenerated with `python tools/generate_hero_ability_files.py` (see `tools/README.md`).

## Usage Guide
In accordance with the Apache License 2.0.

## Contribution Guide
Contributions are welcome under the Apache License 2.0.

### General
General improvements to UI and script utility functions are welcome, but will be
curated. Inclusion of TypeScript or other XYZLanguage → Lua transcompiling is not
welcome — this project does not need extra stack complexity that requires maintenance.

### Plugins
Plugin contributions are absolutely welcome. Each plugin needs to follow simple rules:
- **No side effects!** If the plugin is disabled, it should do nothing. The Init
  function is always called at the custom game settings screen; `StateRegistrations`
  and `CmdRegistrations` are not called at all if your plugin is disabled.
- **Clean up UI when disabled!** If you add UI in panorama's `custom_ui_manifest.xml`,
  hide/remove it when your plugin is disabled. Fetch your plugin settings from the
  `plugin_settings` net table and check `.enabled.VALUE == 0`.

### Abilities
Keep abilities Lua-driven where possible. Custom community abilities live under their
author's namespace, e.g. `drteaspoon_multicast` in `/abilities/drteaspoon/multicast/`.
Per-hero base ability tuning lives under `scripts/npc/heroes/<hero>/`.

### Items
Welcome if left unpurchasable. Even items not added to the shop remain visible when
searched and may cause crashes in some cases.

### Units
Sure!

# Credits

## Created by
**OneLostHero** — Meme Mode remake.

## Inspired by
**MGMod** by DrTeaSpoon and its contributors (Abraham Blink'in, SwordBacon, Fahr3n,
Diellan). Meme Mode would not exist without their work.

## Indirect Authors
Timers Library by bmddota.</br>
David Kolf's JSON module for Lua 5.1/5.2 by David Heiko Kolf.

# Special Thanks
Thank you to **DrTeaSpoon** for the amazing work on MGMod.</br>
Thank you to **Fahr3n** and his **PWR Team**, **Flasaro**, **Moosestache**, **Mr.BadHabits**,
**Occupational Hazard**.</br>
And to the Mod Dota community ([moddota.com](https://moddota.com/)) for the invaluable
reference and support. <3
