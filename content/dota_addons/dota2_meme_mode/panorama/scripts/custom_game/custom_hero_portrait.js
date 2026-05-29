"use strict";
// Custom hero portrait fix (robust).
//
// Server-only custom heroes (npc_heroes_custom.txt + BaseClass) have no client
// portrait, so the vanilla pick-screen portrait, the hero grid card, and the
// in-game top-bar image render blank. We override them with the static PNGs we
// ship under panorama/images/heroes/ for our custom heroes only.
//
// Two strategies (robust to Valve panel-id changes):
//   1) Recursively patch any panel that exposes .heroname matching a custom hero
//      (covers grid cards + top-bar images regardless of exact ids).
//   2) Explicitly patch the inspect portrait from the LOCAL player's selection
//      (that big portrait panel usually has no .heroname).
//
// Requires util.js (GetDotaHud / FindDotaHudElement) included first.
// Pattern: OAA top_bar_fix.js + dota_imba vanilla_hero_selection.js.

var CUSTOM_HEROES = {
    "npc_dota_hero_flasaro": true,
};

function IsCustomHero(name) {
    return name != null && name !== "" && CUSTOM_HEROES[name] === true;
}
function SelectionImg(name) { return 'url("file://{images}/heroes/selection/' + name + '.png")'; }
function TopBarImg(name)    { return 'url("file://{images}/heroes/' + name + '.png")'; }

var g_diagDone = false;

function SetBg(panel, url) {
    if (!panel) return;
    panel.style.backgroundImage = url;
    panel.style.backgroundSize = "100% 100%";
    panel.style.backgroundPosition = "50% 50%";
    panel.style.backgroundRepeat = "no-repeat";
}

// Strategy 1: recursive patch by .heroname.
function PatchByHeroname(panel, depth) {
    if (!panel || depth > 50) return;
    var hero = null;
    try { hero = panel.heroname; } catch (e) {}
    if (IsCustomHero(hero)) {
        SetBg(panel, SelectionImg(hero));
        if (!g_diagDone) $.Msg("[custom_hero_portrait] patched .heroname panel id='" + panel.id + "' hero=" + hero);
    }
    var kids = null;
    try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) PatchByHeroname(kids[i], depth + 1); }
}

// Strategy 2: explicit inspect portrait from the local player's selection.
function PatchInspectPortrait(hud) {
    var pid = Players.GetLocalPlayer();
    if (pid < 0) return;
    var info = Game.GetPlayerInfo(pid);
    if (!info) return;
    var sel = info.player_selected_hero || info.possible_hero_selection || "";
    if (!IsCustomHero(sel)) return;

    var inspect = hud.FindChildTraverse("HeroInspectInfo");
    if (!inspect) return;

    // One-time: dump the inspect subtree ids so we can target precisely if needed.
    if (!g_diagDone) {
        $.Msg("[custom_hero_portrait] HeroInspectInfo children:");
        DumpIds(inspect, 0);
    }

    // Try the known portrait panel id, then fall back to patching the whole subtree.
    var portrait = inspect.FindChildTraverse("HeroPortrait");
    if (portrait) SetBg(portrait, SelectionImg(sel));
    var movie = inspect.FindChildTraverse("HeroModel") || inspect.FindChildTraverse("HeroMovie");
    if (movie) SetBg(movie, SelectionImg(sel));
}

function DumpIds(panel, depth) {
    if (!panel || depth > 4) return;
    var pad = "";
    for (var d = 0; d < depth; d++) pad += "  ";
    $.Msg("[custom_hero_portrait] " + pad + "id='" + panel.id + "' type=" + panel.paneltype);
    var kids = null;
    try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) DumpIds(kids[i], depth + 1); }
}

function Run() {
    var hud = GetDotaHud();
    if (!hud) return;

    var pg = hud.FindChildTraverse("PreGame") || hud.FindChildTraverse("HeroPickScreen");
    if (pg) PatchByHeroname(pg, 0);

    PatchInspectPortrait(hud);

    var rows = ["RadiantTeamPlayers", "DireTeamPlayers"];
    for (var t = 0; t < rows.length; t++) {
        var c = hud.FindChildTraverse(rows[t]);
        if (!c) continue;
        for (var j = 0; j < c.GetChildCount(); j++) {
            var child = c.GetChild(j);
            var img = child ? child.FindChildTraverse("HeroImage") : null;
            var hn = null;
            try { hn = img ? img.heroname : null; } catch (e) {}
            if (img && IsCustomHero(hn)) SetBg(img, TopBarImg(hn));
        }
    }

    g_diagDone = true;
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.5, Tick); }
    $.Schedule(0.5, Tick);
})();
