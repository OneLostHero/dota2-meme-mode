"use strict";
// Custom hero portrait fix.
//
// Panorama uses the SHORT hero name (e.g. "flasaro") for selection + panel .heroname;
// image paths use the full "npc_dota_hero_<name>". Match short, build full.
//
// - Any DOTAHeroImage with a custom .heroname (grid cards, top bar) is blank for a
//   custom hero, so we set a background image (shows through). Done across the HUD.
// - Moving-portrait render panels (DOTAHeroMovie / DOTAScenePanel / DOTAPortrait) in
//   the pick screen render nothing for a custom hero: we hide each and overlay the
//   static image. This covers BOTH the hover inspect AND the selected-hero preview.

var CUSTOM_SHORT = {
    "flasaro": true,
    "onelosthero": true,
};

function ShortName(n) { if (n == null) return ""; return n.indexOf("npc_dota_hero_") === 0 ? n.substring(14) : n; }
function FullName(n)  { if (n == null || n === "") return ""; return n.indexOf("npc_dota_hero_") === 0 ? n : ("npc_dota_hero_" + n); }
function IsCustomHero(n) { var s = ShortName(n); return s !== "" && CUSTOM_SHORT[s] === true; }
function SelectionImg(n) { return 'url("file://{images}/heroes/selection/' + FullName(n) + '.png")'; }

function SetBg(p, url) {
    if (!p) return;
    p.style.backgroundImage = url;
    p.style.backgroundSize = "100% 100%";
    p.style.backgroundPosition = "50% 50%";
    p.style.backgroundRepeat = "no-repeat";
}

function Root() {
    var p = $.GetContextPanel();
    var g = 0;
    while (p && p.GetParent && p.GetParent() && g < 300) { p = p.GetParent(); g++; }
    return p;
}
function LocalSelection() {
    var pid = Players.GetLocalPlayer();
    var info = pid >= 0 ? Game.GetPlayerInfo(pid) : null;
    return info ? (info.player_selected_hero || info.possible_hero_selection || "") : "";
}

// Background-image patch for any DOTAHeroImage-style panel with a custom .heroname.
function PatchByHeroname(panel, depth) {
    if (!panel || depth > 80) return;
    var h = null; try { h = panel.heroname; } catch (e) {}
    if (IsCustomHero(h)) SetBg(panel, SelectionImg(h));
    var kids = null; try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) PatchByHeroname(kids[i], depth + 1); }
}

// Collect moving-portrait render panels (don't recurse into them).
function CollectRenderPanels(root, depth, out) {
    if (!root || depth > 16) return;
    var pt = null; try { pt = root.paneltype; } catch (e) {}
    if (pt === "DOTAScenePanel" || pt === "DOTAHeroMovie" || pt === "DOTAPortrait") { out.push(root); return; }
    var kids = null; try { kids = root.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) CollectRenderPanels(kids[i], depth + 1, out); }
}

function DirectChildById(parent, id) {
    try { for (var i = 0; i < parent.GetChildCount(); i++) { var c = parent.GetChild(i); if (c && c.id === id) return c; } } catch (e) {}
    return null;
}

function OverlayRenderPanel(render, sel, custom) {
    var parent = render.GetParent();
    if (!parent) return;
    var overlay = DirectChildById(parent, "CustomHeroPortraitOverlay");
    if (custom) {
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

function Run() {
    try {
        var root = Root();
        if (!root) return;

        // Grid cards + top-bar (and any DOTAHeroImage) across the whole HUD.
        PatchByHeroname(root, 0);

        // Pick-screen moving portraits (hover inspect + selected preview).
        var pg = root.FindChildTraverse("PreGame") || root.FindChildTraverse("HeroPickScreen");
        if (pg) {
            var sel = LocalSelection();
            var custom = IsCustomHero(sel);
            var panels = [];
            CollectRenderPanels(pg, 0, panels);
            for (var i = 0; i < panels.length; i++) OverlayRenderPanel(panels[i], sel, custom);
        }
    } catch (e) {}
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.3, Tick); }
    $.Schedule(0.3, Tick);
})();
