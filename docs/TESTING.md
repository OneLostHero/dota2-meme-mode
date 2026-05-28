# Testing Dota 2 - Meme Mode locally

The addon lives in your Dota install as `dota2_meme_mode` (both the `game/` and
`content/` trees). To test it you run Dota's **Workshop Tools** build and launch the
custom game from the in-game console.

## One-time setup

1. **Install the Dota 2 Workshop Tools** (if not already):
   - Steam → Library → right-click **Dota 2** → **Properties → DLC** (or the
     Library "Tools" filter) → enable/install **Dota 2 Workshop Tools**. It's a large
     download.
2. **Make sure this repo's addon is in your Dota install.** The folders must be at:
   - `...\dota 2 beta\game\dota_addons\dota2_meme_mode`
   - `...\dota 2 beta\content\dota_addons\dota2_meme_mode`
   If you're working out of this repo elsewhere, copy/symlink those two folders into
   the Dota install (the `game/` and `content/` halves must share the name
   `dota2_meme_mode`).

## Launch the tools build

1. Start Dota 2. In the launch radial, choose **Launch Dota 2 - Tools**.
2. Pick the addon **dota2_meme_mode** in the Asset Browser / addon dropdown if prompted.
3. Open the in-game console with the **`** key (backtick, above Tab) — on newer
   installs the key may be **\\**. (If neither opens it, enable the console in
   Settings → Options → Advanced → "Enable developer console".)

## Start a match

In the console, run:

```
dota_launch_custom_game dota2_meme_mode dota
```

`dota` is the map. Available maps (from `addoninfo.txt`): `dota`, `boosted`,
`dota24`, `boosted24`. Use `dota` for the standard map.

Then fill the lobby so the game can start without other players:

```
dota_bot_populate      # fills both teams with passive bots up to the limit
```

(Or join a side yourself with `jointeam good` / `jointeam bad`, then
`dota_start_game` if needed.)

## Verifying the per-hero ability edits

1. Before launching, edit a value in a hero file and save, e.g. in
   `game\dota_addons\dota2_meme_mode\scripts\npc\heroes\riki\abilities.txt`
   set an ability's `"AbilityCooldown"` to `"1 1 1 1"`. Do the same for
   `queenofpain` and `skeleton_king`.
2. Launch as above and pick/spawn those heroes. Use `-givehero` or the hero-selection
   UI; you can also use `dota_create_unit` / the mode's hero builder.
3. Confirm the modified ability's cooldown is ~1s in-game, and that the ability icon
   and name display correctly.
4. **Watch for errors:** open `...\dota 2 beta\game\dota\console.log` (or the VConsole
   window) and check there are **no KeyValues parse errors** as the game loads. KV
   errors mean a malformed hero file.
5. **Revert** your test edits by regenerating clean files:
   ```
   python tools\generate_hero_ability_files.py
   ```

## Useful console commands while testing

- `dota_bot_populate` — fill teams with bots.
- `jointeam good` / `jointeam bad` / `jointeam spectator`.
- `dota_dev hero_refresh` — refresh cooldowns/mana so you can re-cast quickly.
- `dota_create_unit npc_dota_hero_riki` — spawn a hero/unit.
- `-givehero <name>` (chat) if the mode supports it; otherwise use the hero builder UI.
- `r_farclip 10000` etc. are not needed; ignore.

## Notes after the rebrand

- The custom game's display name is now **"Dota 2 - Meme Mode"**
  (`resource/addon_english.txt` → `addon_game_name`). The folder/launch name is
  `dota2_meme_mode`.
- The loading-screen and DVD logos are **placeholders** (`meme_mode_logo.png`,
  `meme_mode_logo_outline.png`). Replace the artwork anytime, keeping the filenames,
  or regenerate with `python tools\make_placeholder_logo.py`.
- The old cloud preset save/load (external server) was removed. Host presets now save
  **in-session only** (the `save_slots` net table). Cross-session preset persistence
  would need a storage backend — a future task.
- The in-game **GitHub** link button now points to `https://github.com/OneLostHero`
  (placeholder — update to your real repo). The **Discord** and **Steam** link buttons
  still point at the original community/store pages; update those in
  `content\dota_addons\dota2_meme_mode\panorama\layout\custom_game\links.xml` if you
  want your own.

## Sources
- [Playing Addons — Valve Developer Community](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Addon_Overview/Playing_Addons)
- [Simulating Players During Development — Valve Developer Community](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Addon_Overview/Simulating_Players_During_Development)
- [Getting Started — ModDota](https://moddota.com/getting-started)
- [Dota 2 Workshop Tools — Dota 2 Wiki](https://dota2.fandom.com/wiki/Dota_2_Workshop_Tools)
