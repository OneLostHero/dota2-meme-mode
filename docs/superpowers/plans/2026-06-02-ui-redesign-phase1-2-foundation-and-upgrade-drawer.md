# Meme Mode UI Redesign — Phase 1 (Visual Tokens) + Phase 2 (Upgrade Drawer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the shared "Refined Chaos" visual-language CSS, then turn the always-on in-game upgrade picker (`upgrade.xml`/`.js`/`.css`) into a collapsible, named, searchable HUD drawer that handles ~199 entries without eating the screen.

**Architecture:** Pure Panorama (Dota custom-game UI). One new shared stylesheet of reusable classes (Panorama's CSS dialect — use literal-valued classes, not CSS variables). The upgrade picker is modified in place: collapse chrome + edge tab in the XML, restyle in the CSS, and ability-name + search + collapse logic in the JS. The picker reads upgrade options from the `player_booster` net table (key `<localPlayerId>d`) and rebuilds the `#Upgrades` list on every update — search/collapse must survive those rebuilds.

**Tech Stack:** Panorama XML layouts, Panorama CSS (`.vcss`), Panorama JS (V8). No automated test harness exists for Panorama — **verification is in-client visual inspection** (launch the custom game, observe). Use the `/run` skill or launch `dota2_meme_mode` on map `dota`, enable the `boosted` plugin in setup, pick a hero, and reach the in-game HUD.

---

## Important context for the implementer

- **No unit tests.** Do not write or "run" tests. Each task ends with a concrete in-client visual check and a commit.
- **Build/deploy reality:** the repo is symlinked into the Dota install; editing files under `content/.../panorama/` is picked up on a fresh game launch (Panorama recompiles on launch). You must relaunch the custom game to see changes.
- **The `boosted` plugin must be enabled** in the setup screen for the upgrade picker to appear (`upgrade.js` hides itself if `plugin_settings.boosted.enabled.VALUE == 0`).
- **Files in play (all under `content/dota_addons/dota2_meme_mode/panorama/`):**
  - `layout/custom_game/upgrade.xml` — the `PersonalUpgradeScreen` + `UpgradeOption` snippet.
  - `scripts/custom_game/upgrade.js` — builds rows from `player_booster`; `UpgradeOptionNew(data)` creates one row; `UpgradeOptionsNew()` rebuilds the list.
  - `styles/custom_game/upgrade.css` — current styling.
  - `styles/custom_game/meme_ui.css` — **new** shared token stylesheet (Phase 1).
- **Row data shape** (`data` passed to `UpgradeOptionNew`): `{ ability: "<ability_or_item_name>", key: "<stat_key>", upgrade: <pct number>, current: ..., current_mult: ..., rarity: 1|2|3|4, allow_ban: bool, id: <number> }`. The localized ability title is `#DOTA_Tooltip_Ability_<ability>` (spells) or `#DOTA_Tooltip_<item>` (items).

---

## Phase 1 — Refined Chaos visual tokens

### Task 1: Create the shared token stylesheet

**Files:**
- Create: `content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/meme_ui.css`

Reusable classes (literal values — do not rely on CSS variables in Panorama). These are the tokens every redesigned panel will use.

- [ ] **Step 1: Create the stylesheet**

```css
/* meme_ui.css — shared "Refined Chaos" tokens. Include alongside a panel's own .css.
   Clarity-first surfaces; meme personality lives in the accent colors below. */

.meme-panel {
    background-color: #15171c;
    border: 1px solid #2a2f3a;
    border-radius: 8px;
    overflow: noclip clip;
}

.meme-header {
    flow-children: right;
    vertical-align: center;
    padding: 8px 10px;
    background-color: gradient( linear, 0% 0%, 0% 100%, from( #1b1e26 ), to( #15171c ) );
    border-bottom: 1px solid #2a2f3a;
}

.meme-header-title {
    color: #c8ff5e;
    font-size: 15px;
    font-weight: bold;
    letter-spacing: 0.5px;
    vertical-align: center;
}

.meme-row {
    flow-children: right;
    vertical-align: center;
    padding: 6px 8px;
    border-bottom: 1px solid #20242e;
}

.meme-label-primary {
    color: #e8ebf0;
    font-size: 14px;
    vertical-align: center;
}

.meme-label-secondary {
    color: #7a8190;
    font-size: 11px;
    vertical-align: center;
}

.meme-pill-pos {
    color: #7CFC00;
    font-weight: bold;
    background-color: #1f3a1f;
    border-radius: 10px;
    padding: 2px 7px;
    vertical-align: center;
}

.meme-pill-neg {
    color: #ff6b6b;
    font-weight: bold;
    background-color: #3a1f1f;
    border-radius: 10px;
    padding: 2px 7px;
    vertical-align: center;
}

.meme-input {
    background-color: #0e1014;
    border: 1px solid #2c3344;
    border-radius: 5px;
    color: #e8ebf0;
    font-size: 13px;
    padding: 4px 7px;
}
```

- [ ] **Step 2: Verify it loads (in-client)**

This file defines classes only; nothing references it yet, so it cannot break anything. Confirm it compiles by including it in Task 2 (the launch there will surface any CSS parse error in the console as `Failed to load ... meme_ui.css`).

- [ ] **Step 3: Commit**

```bash
git add content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/meme_ui.css
git commit -m "feat(ui): add shared Refined Chaos token stylesheet (meme_ui.css)"
```

---

## Phase 2 — Upgrade drawer

### Task 2: Make the picker a collapsible drawer (chrome + edge tab)

Wrap the always-on `PersonalUpgradeScreen` in drawer chrome with a header and a collapse toggle, plus an edge tab that reopens it when collapsed.

**Files:**
- Modify: `content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml`
- Modify: `content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css`
- Modify: `content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js`

- [ ] **Step 1: Add the meme_ui include + drawer structure in upgrade.xml**

Replace the `<styles>` block and the `PersonalUpgradeScreen` panel. Keep the existing `UpgradeOption` snippet unchanged in this task.

```xml
	<styles>
		<include src="file://{resources}/styles/custom_game/meme_ui.css" />
		<include src="file://{resources}/styles/custom_game/upgrade.css" />
	</styles>
```

```xml
	<Panel class="PersonalUpgradeScreen" hittest="false" visible="true">
		<!-- Edge tab: shown only when the drawer is collapsed; click to reopen -->
		<Button id="UpgradeDrawerTab" class="UpgradeDrawerTab" hittest="true">
			<Label id="UpgradeDrawerTabText" text="⚡" />
		</Button>

		<Panel id="UpgradeDrawer" class="meme-panel UpgradeDrawer" hittest="true">
			<Panel class="meme-header" hittest="true">
				<Label class="meme-header-title" text="⚡ ABILITY UPGRADES" />
				<Panel id="UpgradeDrawerQueued" class="UpgradeDrawerQueued">
					<Label id="QueuedUpgradesText" text="0" />
				</Panel>
				<Button id="UpgradeDrawerCollapse" class="UpgradeDrawerCollapse">
					<Label text="◀" />
				</Button>
			</Panel>

			<!-- Reserved slot for the currency balance + Convert button (Phase 3 / currency plan).
			     Left empty here on purpose so the currency phase can drop in without re-layout. -->
			<Panel id="UpgradeDrawerBalanceSlot" class="UpgradeDrawerBalanceSlot" />

			<Panel id="Upgrades" />
		</Panel>
	</Panel>
```

Note: `QueuedUpgrades` (the old counter panel id) is renamed to `UpgradeDrawerQueued`, but the inner `QueuedUpgradesText` label id is preserved so `upgrade.js`'s `QueuedUpgradesText` lookup still works. The old `QueuedUpgrades` mouseover tooltip is rewired in Step 3.

- [ ] **Step 2: Replace the drawer styling in upgrade.css**

Replace the `.PersonalUpgradeScreen`, `#Upgrades`, and `#QueuedUpgrades`/`#QueuedUpgradesText` rules with drawer styling. Leave `.UpgradeOption`, rarity classes, `.OptionButton*`, `#AbilityChangeReport`, and `.hidden` as-is for now.

```css
  .PersonalUpgradeScreen{
   margin-top: 110px;
   horizontal-align: left;
   vertical-align: top;
   flow-children: right;
  }

  .UpgradeDrawer{
   width: 300px;
   max-height: 620px;
   flow-children: down;
  }
  .UpgradeDrawer.collapsed{
   visibility: collapse;
   width: 0px;
  }

  #Upgrades{
   flow-children: down;
   overflow: noclip scroll;
   max-height: 520px;
  }

  .UpgradeDrawerQueued{
   margin-left: 8px;
   border-radius: 10px;
   background-color: #a36a00;
   padding: 1px 8px;
   vertical-align: center;
  }
  #QueuedUpgradesText{
   color: rgb(255,255,255);
   font-size: 13px;
   font-weight: bold;
  }

  #UpgradeDrawerCollapse{
   horizontal-align: right;
   width: 22px;
   height: 22px;
   vertical-align: center;
  }
  #UpgradeDrawerCollapse Label{ color: #7a8190; font-size: 13px; vertical-align: center; horizontal-align: center; }
  #UpgradeDrawerCollapse:hover Label{ color: #c8ff5e; }

  .UpgradeDrawerBalanceSlot{ flow-children: right; }

  /* Edge tab: hidden unless the screen carries the 'drawer-collapsed' state */
  .UpgradeDrawerTab{
   visibility: collapse;
   width: 0px;
  }
  .PersonalUpgradeScreen.drawer-collapsed .UpgradeDrawerTab{
   visibility: visible;
   width: 26px;
   height: 64px;
   vertical-align: center;
   background-color: gradient( linear, 0% 0%, 0% 100%, from( #1b1e26 ), to( #15171c ) );
   border: 1px solid #2a2f3a;
   border-radius: 0px 6px 6px 0px;
  }
  #UpgradeDrawerTabText{ color: #c8ff5e; font-size: 16px; horizontal-align: center; vertical-align: center; }
```

- [ ] **Step 3: Wire collapse/expand in upgrade.js**

At the top of `upgrade.js`, the existing handle lookups are:

```js
var QueuedUpgradesText = $.GetContextPanel().FindChildInLayoutFile("QueuedUpgradesText");
var QueuedUpgrades = $.GetContextPanel().FindChildInLayoutFile("QueuedUpgrades");
```

Replace those two lines with handles for the new structure and a collapse helper:

```js
var QueuedUpgradesText = $.GetContextPanel().FindChildInLayoutFile("QueuedUpgradesText");
var Screen = $.GetContextPanel().FindChildInLayoutFile("PersonalUpgradeScreen") || $.GetContextPanel();
var Drawer = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawer");
var DrawerTab = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerTab");
var DrawerCollapse = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerCollapse");
var DrawerQueued = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerQueued");

function SetCollapsed(collapsed) {
    Drawer.SetHasClass("collapsed", collapsed);
    Screen.SetHasClass("drawer-collapsed", collapsed);
}
```

In the `init()` IIFE, inside the `else` branch (the not-disabled path, after `boost_player_recheck();`), replace the old `QueuedUpgrades.SetPanelEvent(...)` tooltip block with collapse wiring and the queued tooltip on the new panel:

```js
        DrawerCollapse.SetPanelEvent('onactivate', function () { SetCollapsed(true); });
        DrawerTab.SetPanelEvent('onactivate', function () { SetCollapsed(false); });

        DrawerQueued.SetPanelEvent('onmouseover', function () {
            $.DispatchEvent("DOTAShowTextTooltip", DrawerQueued, $.Localize("#Boosted_queue"));
        });
        DrawerQueued.SetPanelEvent('onmouseout', function () {
            $.DispatchEvent("DOTAHideTextTooltip", DrawerQueued);
        });
```

- [ ] **Step 4: Verify in-client**

Launch `dota2_meme_mode` (map `dota`), enable the **Boosted** plugin in setup, pick a hero, reach the HUD. Expected:
- The upgrade list now sits inside a dark titled panel ("⚡ ABILITY UPGRADES") on the left, not a bare stack.
- Clicking **◀** collapses the whole panel to a thin **⚡** edge tab; clicking the tab reopens it.
- The queued count still shows and its hover tooltip still appears.
- Console shows no `Failed to load ... meme_ui.css` / `upgrade.css` parse errors.

- [ ] **Step 5: Commit**

```bash
git add content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js
git commit -m "feat(ui): make in-game upgrade picker a collapsible drawer with header + edge tab"
```

---

### Task 3: Show the ability name on each row + Refined Chaos row styling

Currently each `UpgradeOption` shows only the icon and the stat key (`UpgradeOptionLabel`). Add the ability/item display name as a primary label, with the stat as secondary.

**Files:**
- Modify: `content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml` (the `UpgradeOption` snippet)
- Modify: `content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js` (`UpgradeOptionNew`)
- Modify: `content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css`

- [ ] **Step 1: Add a name label + text column to the snippet**

In `upgrade.xml`, replace the `UpgradeOption` snippet's single `UpgradeOptionLabel` with a two-line text column (name on top, stat below). Keep image and buttons.

```xml
		<snippet name="UpgradeOption">
			<Panel class="UpgradeOption meme-row">
				<DOTAAbilityImage id="UpgradeOptionImage" class="OptionImage" />
				<DOTAItemImage id="UpgradeOptionImageItem" class="OptionImage" />
				<Button id="AbilityChangeReport"/>
				<Panel class="UpgradeOptionText">
					<Label id="UpgradeOptionAbilityName" class="meme-label-primary" text="ability" />
					<Label id="UpgradeOptionLabel" class="meme-label-secondary" html="true" text="key_value" />
				</Panel>
				<Button id="OptionButtonPlus" class="OptionButton">
					<Label class="OptionNumText" id="OptionButtonPlusText" text="option_plus" />
				</Button>
				<Button id="OptionButtonMinus" class="OptionButton">
					<Label class="OptionNumText" id="OptionButtonMinusText" text="option_minus" />
				</Button>
				<Button id="OptionButtonBan" class="OptionButton">
					<Label class="OptionNumText" id="OptionButtonBanText" text="X" />
				</Button>
			</Panel>
		</snippet>
```

- [ ] **Step 2: Set the ability name in upgrade.js**

In `UpgradeOptionNew(data)`, just after the `UpgradeOptionLabel` lookup at line 38 (`var UpgradeOptionLabel = upgradePanel.FindChildTraverse("UpgradeOptionLabel");`), add name resolution:

```js
    var UpgradeOptionAbilityName = upgradePanel.FindChildTraverse("UpgradeOptionAbilityName");
    var nameLoc = data.ability.includes("item_")
        ? $.Localize("#DOTA_Tooltip_" + data.ability)
        : $.Localize("#DOTA_Tooltip_Ability_" + data.ability);
    // Fall back to a de-prefixed, readable raw name if no localization exists.
    if (nameLoc.indexOf("#DOTA_Tooltip") === 0) {
        nameLoc = data.ability.replace("item_", "").replace(/_/g, " ");
    }
    UpgradeOptionAbilityName.text = nameLoc;
    // Searchable text for Task 4 (ability name + stat key), set once per row.
    upgradePanel.SetAttributeString("searchtext", (nameLoc + " " + data.key).toLowerCase());
```

(The existing code that sets `UpgradeOptionLabel.text` to the stat key/localized stat remains unchanged — it now renders as the secondary line.)

- [ ] **Step 3: Style the text column in upgrade.css**

Add:

```css
  .UpgradeOptionText{
   flow-children: down;
   vertical-align: center;
   margin-left: 6px;
   margin-right: 6px;
   width: 130px;
  }
  #UpgradeOptionLabel{
   letter-spacing: 0px;
   text-align: left;
   text-shadow: 1px 1px 1px rgb(0,0,0);
  }
  #UpgradeOptionAbilityName{
   text-align: left;
  }
```

(The old centered `#UpgradeOptionLabel` rule from Task 2's file can stay; this overrides alignment. If both rules conflict confusingly, delete the old `#UpgradeOptionLabel` block.)

- [ ] **Step 4: Verify in-client**

Relaunch, enable Boosted, reach HUD with upgrade options present. Expected: each row shows the **ability/item name** as the bold top line and the **stat** (e.g., "radius") as the muted line below, with the ± buttons unchanged. Items show their item name; spells show their spell name.

- [ ] **Step 5: Commit**

```bash
git add content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css
git commit -m "feat(ui): show ability/item name on each upgrade row (name primary, stat secondary)"
```

---

### Task 4: Add search that filters the upgrade list

Add a search box in the drawer header area that filters rows by ability name or stat. Must survive list rebuilds (the list re-creates on every `player_booster` update).

**Files:**
- Modify: `content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml`
- Modify: `content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js`
- Modify: `content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css`

- [ ] **Step 1: Add the search TextEntry to the drawer**

In `upgrade.xml`, add a search row directly above `<Panel id="Upgrades" />` inside `UpgradeDrawer`:

```xml
			<Panel class="UpgradeSearchRow">
				<TextEntry id="UpgradeSearch" class="meme-input UpgradeSearch" placeholder="Search upgrades…" />
			</Panel>
```

- [ ] **Step 2: Implement filtering in upgrade.js**

Add a search handle near the other handles (top of file):

```js
var UpgradeSearch = $.GetContextPanel().FindChildInLayoutFile("UpgradeSearch");
var searchQuery = "";
```

Add the filter function (place near `UpgradeOptionNew`):

```js
function ApplyUpgradeFilter() {
    var kids = Upgrades.Children();
    for (var i = 0; i < kids.length; i++) {
        var txt = kids[i].GetAttributeString("searchtext", "");
        var match = (searchQuery === "" || txt.indexOf(searchQuery) !== -1);
        kids[i].SetHasClass("filtered-out", !match);
    }
}
```

Wire the TextEntry in the `init()` `else` branch (alongside the Task 2 collapse wiring):

```js
        UpgradeSearch.SetPanelEvent('ontextentrychanged', function () {
            searchQuery = UpgradeSearch.text.toLowerCase();
            ApplyUpgradeFilter();
        });
```

The list rebuilds in `UpgradeOptionsNew` via `Upgrades.RemoveAndDeleteChildren()` then `UpgradeOptionNew(...)` per option. Re-apply the filter after a rebuild: at the end of the `for (let key in data)` loop body in `UpgradeOptionsNew` (right after the loop that calls `UpgradeOptionNew`/sets `QueuedUpgradesText`), add:

```js
                        ApplyUpgradeFilter();
```

- [ ] **Step 3: Style the search row + filtered state in upgrade.css**

```css
  .UpgradeSearchRow{ padding: 6px 8px; border-bottom: 1px solid #20242e; }
  .UpgradeSearch{ width: 100%; }
  .filtered-out{ visibility: collapse; height: 0px; }
```

- [ ] **Step 4: Verify in-client**

Relaunch, enable Boosted, reach HUD with several upgrade options. Expected:
- A "Search upgrades…" box sits above the list.
- Typing part of an ability name or stat hides non-matching rows live; clearing it restores all.
- When new upgrade options stream in (the list rebuilds), the active filter still applies.

- [ ] **Step 5: Commit**

```bash
git add content/dota_addons/dota2_meme_mode/panorama/layout/custom_game/upgrade.xml content/dota_addons/dota2_meme_mode/panorama/scripts/custom_game/upgrade.js content/dota_addons/dota2_meme_mode/panorama/styles/custom_game/upgrade.css
git commit -m "feat(ui): add search filtering to the upgrade drawer (survives list rebuilds)"
```

---

## Out of scope for this plan (separate plans)

- **Phase 3 — Currency clarity ("Boost Juice"):** balance + `⇄ Convert gold` into `UpgradeDrawerBalanceSlot` (reserved in Task 2), the self-explaining converter, removing the standalone red chip. Touches `currencies.*`.
- **Phase 4 — Setup screen:** labeled preset slots, search + collapsible category groups, the `panorama/localization/addon_english.txt` localization fix. Touches `plugin_settings.*`.
- **Parked entirely:** #1 loading-screen stall (debugging task), #3 cross-session persistence (needs a backend).

## Self-review notes

- **Spec coverage (this slice):** visual tokens ✓ (Task 1); drawer placement/collapse ✓ (Task 2); ability name + row format ✓ (Task 3); search + scroll ✓ (Task 4, scroll already in `#Upgrades`). Currency balance-in-header intentionally deferred to Phase 3 with a reserved slot.
- **~199-row performance:** rows are real panels (no virtualization here). If the HUD hitches with very large counts, a follow-up can cap rendered rows or virtualize; flagged in the spec's risks. Not addressed in this plan.
- **Type/name consistency:** `QueuedUpgradesText` id preserved across tasks; `searchtext` attribute set in Task 3 and read in Task 4; `filtered-out` class defined once (Task 4) and used once.
