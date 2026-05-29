"use strict";
// Custom hero portrait fix.
//
// Grid cards and top-bar hero images are DOTAHeroImage panels and render natively
// from their `heroname` once the PNGs compile (see custom_hero_portrait.css).
//
// The only blank panel is the big pick-screen INSPECT portrait, which is a 3D/movie
// render that shows nothing for a server-only custom hero. Fix: hide that render and
// overlay a DOTAHeroImage whose `heroname` we set -- it draws the compiled portrait.
//
// Requires util.js (GetDotaHud) included first.

var CUSTOM_HEROES = {
    "npc_dota_hero_flasaro": true,
    "npc_dota_hero_onelosthero": true,
};

function IsCustomHero(name) {
    return name != null && name !== "" && CUSTOM_HEROES[name] === true;
}

// The vanilla render panel inside the inspect portrait (3D scene / movie / portrait).
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

function Run() {
    var hud = GetDotaHud();
    if (!hud) return;
    var inspect = hud.FindChildTraverse("HeroInspectInfo");
    if (!inspect) return;

    var render = FindRenderPanel(inspect, 0);
    var parent = render ? render.GetParent() : null;
    if (!parent) return; // don't risk covering the stats panel if no render panel found

    var sel = LocalSelection();
    var img = parent.FindChildTraverse("CustomHeroPortraitImage");

    if (IsCustomHero(sel)) {
        if (render) render.style.opacity = "0.0";
        if (!img) {
            img = $.CreatePanel("DOTAHeroImage", parent, "CustomHeroPortraitImage", { heroimagestyle: "portrait" });
            img.style.position = "0px 0px 0px";
            img.style.width = "100%";
            img.style.height = "100%";
            img.style.zIndex = "50";
        }
        if (img.heroname !== sel) {
            try { img.heroname = sel; } catch (e) {}
        }
        img.visible = true;
    } else {
        if (img) img.visible = false;
        if (render) render.style.opacity = "1.0";
    }
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.3, Tick); }
    $.Schedule(0.3, Tick);
})();
