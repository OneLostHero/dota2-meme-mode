"use strict";
// Custom hero portrait fix.
//
// Custom heroes (server-only, defined in npc_heroes_custom.txt with a BaseClass)
// have no client-side portrait, so the VANILLA pick screen's big inspect portrait
// and the in-game top-bar hero image render blank. We override them with the
// static PNGs shipped under panorama/images/heroes/ for our custom heroes only.
//
// Pattern: OAA top_bar_fix.js + dota_imba vanilla_hero_selection.js.
// Requires util.js (FindDotaHudElement) included before this script.

// Custom heroes that need a static portrait. Add new custom heroes here.
var CUSTOM_HEROES = {
    "npc_dota_hero_flasaro": true,
};

function IsCustomHero(name) {
    return name != null && name !== "" && CUSTOM_HEROES[name] === true;
}

// Big portrait in the pick-screen inspect panel (HeroInspectInfo > HeroPortrait).
function UpdateInspectPortrait(heroname) {
    if (!IsCustomHero(heroname)) return;
    var inspect = FindDotaHudElement("HeroInspectInfo");
    if (!inspect) return;
    var portrait = inspect.FindChildTraverse("HeroPortrait");
    if (!portrait) return;
    portrait.style.backgroundImage = 'url("file://{images}/heroes/selection/' + heroname + '.png")';
    portrait.style.backgroundSize = "100% 100%";
}

// In-game top-bar hero images (Radiant + Dire rows).
function UpdateTopBar() {
    var containers = ["RadiantTeamPlayers", "DireTeamPlayers"];
    for (var t = 0; t < containers.length; t++) {
        var container = FindDotaHudElement(containers[t]);
        if (!container) continue;
        for (var j = 0; j < container.GetChildCount(); j++) {
            var child = container.GetChild(j);
            var img = child ? child.FindChildTraverse("HeroImage") : null;
            if (img && IsCustomHero(img.heroname)) {
                img.style.backgroundImage = 'url("file://{images}/heroes/' + img.heroname + '.png")';
                img.style.backgroundSize = "100% 100%";
            }
        }
    }
}

function OnSelectionChanged() {
    var ids = Game.GetAllPlayerIDs();
    for (var i = 0; i < ids.length; i++) {
        var pid = ids[i];
        if (!Players.IsValidPlayerID(pid) || Players.IsSpectator(pid)) continue;
        var info = Game.GetPlayerInfo(pid);
        if (!info) continue;
        var sel = info.player_selected_hero || info.possible_hero_selection || "";
        if (sel !== "") UpdateInspectPortrait(sel);
    }
    UpdateTopBar();
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", OnSelectionChanged);
    GameEvents.Subscribe("dota_player_update_hero_selection", OnSelectionChanged);
    // Periodic safety re-apply: panels are rebuilt as the UI changes, so re-apply
    // on a light timer (the override is a no-op unless a custom hero is involved).
    function Tick() {
        OnSelectionChanged();
        $.Schedule(1.0, Tick);
    }
    $.Schedule(1.0, Tick);
})();
