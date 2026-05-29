"use strict";
// Custom hero portrait fix.
//
// Server-only custom heroes have no client portrait, so:
//   - grid cell + top-bar image: plain images -> fixed simply by pointing them at
//     our static PNGs (which now compile, see custom_hero_portrait.css).
//   - the big pick-screen INSPECT portrait: a 3D/movie render panel that draws a
//     black frame over any background for a custom hero. We can't recolor it, so we
//     HIDE it and lay our static selection image on top.
//
// Requires util.js (GetDotaHud) included first.

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

// --- grid cells + any .heroname panel ---
function PatchByHeroname(panel, depth) {
    if (!panel || depth > 50) return;
    var hero = null;
    try { hero = panel.heroname; } catch (e) {}
    if (IsCustomHero(hero)) SetBg(panel, SelectionImg(hero));
    var kids = null;
    try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) PatchByHeroname(kids[i], depth + 1); }
}

// Find the vanilla render panel (3D scene / movie / portrait) inside a container.
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

// --- big inspect portrait: hide black render, overlay our static image ---
function UpdateInspectPortrait(hud) {
    var inspect = hud.FindChildTraverse("HeroInspectInfo");
    if (!inspect) return;

    var pid = Players.GetLocalPlayer();
    var info = pid >= 0 ? Game.GetPlayerInfo(pid) : null;
    var sel = info ? (info.player_selected_hero || info.possible_hero_selection || "") : "";
    var custom = IsCustomHero(sel);

    var render = FindRenderPanel(inspect, 0);
    var parent = render ? render.GetParent() : null;
    if (!parent) return; // no render panel found -> don't risk covering the stats panel

    var overlay = parent.FindChildTraverse("CustomHeroPortraitOverlay");

    if (custom) {
        if (render) render.style.opacity = "0.0";
        if (!overlay) {
            overlay = $.CreatePanel("Panel", parent, "CustomHeroPortraitOverlay");
            overlay.style.position = "0px 0px 0px";
            overlay.style.width = "100%";
            overlay.style.height = "100%";
            overlay.style.zIndex = "100";
            overlay.style.backgroundSize = "100% 100%";
            overlay.style.backgroundPosition = "50% 50%";
            overlay.style.backgroundRepeat = "no-repeat";
        }
        overlay.style.backgroundImage = SelectionImg(sel);
        overlay.visible = true;
    } else {
        if (overlay) overlay.visible = false;
        if (render) render.style.opacity = "1.0";
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
    var hud = GetDotaHud();
    if (!hud) return;
    var pg = hud.FindChildTraverse("PreGame") || hud.FindChildTraverse("HeroPickScreen");
    if (pg) PatchByHeroname(pg, 0);
    UpdateInspectPortrait(hud);
    UpdateTopBar(hud);
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.3, Tick); }
    $.Schedule(0.3, Tick);
})();
