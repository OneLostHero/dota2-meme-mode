"use strict";
// Custom hero portrait fix.
//
// DOTAHeroImage maps heroname -> portrait via the client hero DB, which has no entry
// for a server-only custom hero, so it renders blank even though the PNG compiled.
// So we set the image BY FILE PATH (background-image) on the blank panels -- this
// loads the compiled .vtex_c directly (see custom_hero_portrait.css which compiles
// them). Covers: grid cards + any panel exposing .heroname, and the big inspect
// portrait (a 3D/movie render we hide and overlay).
//
// NOTE: do NOT use util.js GetDotaHud here -- it THROWS if it can't find the 'Hud'
// root, which would kill this script. We use our own non-throwing finder + try/catch.

var CUSTOM_HEROES = {
    "npc_dota_hero_flasaro": true,
    "npc_dota_hero_onelosthero": true,
};

function IsCustomHero(name) {
    return name != null && name !== "" && CUSTOM_HEROES[name] === true;
}
function SelectionImg(name) { return 'url("file://{images}/heroes/selection/' + name + '.png")'; }
function TopBarImg(name)    { return 'url("file://{images}/heroes/' + name + '.png")'; }

function SetBg(panel, url) {
    if (!panel) return;
    panel.style.backgroundImage = url;
    panel.style.backgroundSize = "100% 100%";
    panel.style.backgroundPosition = "50% 50%";
    panel.style.backgroundRepeat = "no-repeat";
}

// Non-throwing HUD finder (walk to root, then locate 'Hud').
function FindHud() {
    var p = $.GetContextPanel();
    var guard = 0;
    while (p && p.GetParent && p.GetParent() && guard < 200) { p = p.GetParent(); guard++; }
    if (!p) return null;
    try { return p.FindChildTraverse("Hud") || p; } catch (e) { return p; }
}

// Set the bg-by-path on any panel that says it's a custom hero (grid cards, etc.).
function PatchByHeroname(panel, depth) {
    if (!panel || depth > 60) return;
    var hero = null;
    try { hero = panel.heroname; } catch (e) {}
    if (IsCustomHero(hero)) SetBg(panel, SelectionImg(hero));
    var kids = null;
    try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) PatchByHeroname(kids[i], depth + 1); }
}

function FindRenderPanel(root, depth) {
    if (!root || depth > 10) return null;
    var pt = null;
    try { pt = root.paneltype; } catch (e) {}
    if (pt === "DOTAScenePanel" || pt === "DOTAHeroMovie" || pt === "DOTAPortrait") return root;
    var kids = null;
    try { kids = root.Children(); } catch (e) {}
    if (kids) {
        for (var i = 0; i < kids.length; i++) {
            var r = FindRenderPanel(kids[i], depth + 1);
            if (r) return r;
        }
    }
    return null;
}

function LocalSelection() {
    var pid = Players.GetLocalPlayer();
    var info = pid >= 0 ? Game.GetPlayerInfo(pid) : null;
    return info ? (info.player_selected_hero || info.possible_hero_selection || "") : "";
}

// Big inspect portrait: hide the 3D/movie render, overlay a bg-image panel.
function UpdateInspect(hud) {
    var inspect = hud.FindChildTraverse("HeroInspectInfo");
    if (!inspect) return;
    var render = FindRenderPanel(inspect, 0);
    if (!render) return; // if it's a DOTAHeroImage instead, PatchByHeroname covered it
    var parent = render.GetParent();
    if (!parent) return;
    var sel = LocalSelection();
    var overlay = parent.FindChildTraverse("CustomHeroPortraitOverlay");
    if (IsCustomHero(sel)) {
        render.style.opacity = "0.0";
        if (!overlay) {
            overlay = $.CreatePanel("Panel", parent, "CustomHeroPortraitOverlay");
            overlay.style.position = "0px 0px 0px";
            overlay.style.width = "100%";
            overlay.style.height = "100%";
            overlay.style.zIndex = "50";
            overlay.style.backgroundSize = "100% 100%";
            overlay.style.backgroundPosition = "50% 50%";
            overlay.style.backgroundRepeat = "no-repeat";
        }
        overlay.style.backgroundImage = SelectionImg(sel);
        overlay.visible = true;
    } else {
        if (overlay) overlay.visible = false;
        render.style.opacity = "1.0";
    }
}

function UpdateTopBar(hud) {
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
}

function Run() {
    try {
        var hud = FindHud();
        if (!hud) return;
        var pg = hud.FindChildTraverse("PreGame") || hud.FindChildTraverse("HeroPickScreen") || hud;
        PatchByHeroname(pg, 0);
        UpdateInspect(hud);
        UpdateTopBar(hud);
    } catch (e) {}
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.3, Tick); }
    $.Schedule(0.3, Tick);
})();
