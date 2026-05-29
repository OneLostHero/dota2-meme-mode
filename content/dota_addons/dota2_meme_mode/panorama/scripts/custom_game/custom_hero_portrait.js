"use strict";
// Custom hero portrait fix.
//
// Panorama uses the SHORT hero name (e.g. "flasaro") for the selection and for panel
// .heroname, while image paths use the full "npc_dota_hero_<name>". So we match on
// the short name and build the full name for the image path.
//
// Grid cards + top-bar are DOTAHeroImage (blank for a custom hero, so a background
// image shows through). The big inspect portrait is a DOTAHeroMovie that renders
// nothing for a custom hero -> we hide it and overlay our static image.
//
// (Confirmed via on-screen diagnostic: root=DotaHud, HeroInspectInfo/HeroGrid
// reachable, inspect render = DOTAHeroMovie, selection name = "flasaro".)

var CUSTOM_SHORT = {
    "flasaro": true,
    "onelosthero": true,
};

function ShortName(n) { if (n == null) return ""; return n.indexOf("npc_dota_hero_") === 0 ? n.substring(14) : n; }
function FullName(n)  { if (n == null || n === "") return ""; return n.indexOf("npc_dota_hero_") === 0 ? n : ("npc_dota_hero_" + n); }
function IsCustomHero(n) { var s = ShortName(n); return s !== "" && CUSTOM_SHORT[s] === true; }
function SelectionImg(n) { return 'url("file://{images}/heroes/selection/' + FullName(n) + '.png")'; }
function TopBarImg(n)    { return 'url("file://{images}/heroes/' + FullName(n) + '.png")'; }

function PanelW(p) { var w = 0; try { w = p.actuallayoutwidth || 0; } catch (e) {} return w; }
function PanelH(p) { var h = 0; try { h = p.actuallayoutheight || 0; } catch (e) {} return h; }

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

// Lay our static image ON TOP of a custom-hero card. A DOTAHeroImage paints its own
// (blank, for a custom hero) texture OVER its child panels, so an overlay added as a
// CHILD never shows (verified in-game). Add it to the PARENT as a SIBLING instead --
// the pattern UpdateInspect already proves works -- sized in pixels to match the image
// and placed at the image's top-left. The sibling lives in the same slot container, so
// the pick screen's hover scale transform scales it together with the card.
function OverlayOn(panel, hero) {
    var parent = panel.GetParent ? panel.GetParent() : null;
    if (!parent) return;
    var w = Math.round(PanelW(panel)), h = Math.round(PanelH(panel));
    if (w < 1 || h < 1) return; // layout not ready yet
    var ox = 0, oy = 0;
    try { ox = Math.round(panel.actualxoffset) || 0; } catch (e) {}
    try { oy = Math.round(panel.actualyoffset) || 0; } catch (e) {}
    // Unique id per hero so two custom heroes sharing a parent can't collide.
    var id = "ChpStaticOverlay_" + ShortName(hero);
    var ov = null;
    try { ov = parent.FindChild(id); } catch (e) {}
    if (!ov) {
        ov = $.CreatePanel("Panel", parent, id);
        ov.style.zIndex = "60";
        ov.style.backgroundSize = "100% 100%";
        ov.style.backgroundPosition = "50% 50%";
        ov.style.backgroundRepeat = "no-repeat";
        try { ov.hittest = false; } catch (e) {}
    }
    ov.style.position = ox + "px " + oy + "px 0px";
    ov.style.width = w + "px";
    ov.style.height = h + "px";
    ov.style.backgroundImage = SelectionImg(hero);
    ov.visible = true;
}

// Grid cards / any .heroname panel for a custom hero -> set its bg image, and for
// sizable cards (the enlarged hover preview + inspect, NOT tiny grid cells and NOT
// full-screen panels) also overlay the static image on top.
function PatchByHeroname(panel, depth) {
    if (!panel || depth > 80) return;
    var h = null; try { h = panel.heroname; } catch (e) {}
    if (IsCustomHero(h)) {
        SetBg(panel, SelectionImg(h));
        // A DOTAHeroImage draws its own (blank, for a custom hero) render OVER the
        // background, so the bg alone shows nothing -- we must lay the static image on
        // TOP. This includes the small grid cards (~49x84), which are the panels the
        // pick screen CSS-scales up on hover (their base size stays small, so the
        // "enlarged preview" is the same panel). Exclude 0x0 (hidden) and full-screen.
        var w = PanelW(panel), ht = PanelH(panel);
        if (w >= 30 && w <= 700 && ht >= 30 && ht <= 1000) OverlayOn(panel, h);
    }
    var kids = null; try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) PatchByHeroname(kids[i], depth + 1); }
}

function FindRenderPanel(root, depth) {
    if (!root || depth > 12) return null;
    var pt = null; try { pt = root.paneltype; } catch (e) {}
    if (pt === "DOTAScenePanel" || pt === "DOTAHeroMovie" || pt === "DOTAPortrait") return root;
    var kids = null; try { kids = root.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) { var r = FindRenderPanel(kids[i], depth + 1); if (r) return r; } }
    return null;
}

// Big inspect portrait: hide the blank DOTAHeroMovie, overlay our static image.
function UpdateInspect(root) {
    var inspect = root.FindChildTraverse("HeroInspectInfo");
    if (!inspect) return;
    var render = FindRenderPanel(inspect, 0);
    if (!render) return;
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

function UpdateTopBar(root) {
    var rows = ["RadiantTeamPlayers", "DireTeamPlayers"];
    for (var t = 0; t < rows.length; t++) {
        var c = root.FindChildTraverse(rows[t]);
        if (!c) continue;
        for (var j = 0; j < c.GetChildCount(); j++) {
            var ch = c.GetChild(j);
            var img = ch ? ch.FindChildTraverse("HeroImage") : null;
            var hn = null; try { hn = img ? img.heroname : null; } catch (e) {}
            if (img && IsCustomHero(hn)) SetBg(img, TopBarImg(hn));
        }
    }
}

// Only the PICK SCREEN needs these overlays: pre-spawn, the client can't render a
// server-only custom hero, so its grid/inspect/top-row panels are blank. IN-GAME the
// engine renders the portrait natively from the hero's model -- so we must NOT touch
// anything in-game (doing so covered the live hero portrait). Gate on game state.
function IsPickState() {
    var st = -1;
    try { st = Game.GetState(); } catch (e) {}
    return st === DOTA_GAMERULES_STATE_HERO_SELECTION ||
           st === DOTA_GAMERULES_STATE_STRATEGY_TIME;
}

function Run() {
    try {
        if (!IsPickState()) return;
        var root = Root();
        if (!root) return;
        var pg = root.FindChildTraverse("PreGame") || root.FindChildTraverse("HeroPickScreen") || root;
        PatchByHeroname(pg, 0);
        UpdateInspect(root);
        UpdateTopBar(root);
    } catch (e) {}
}

(function () {
    GameEvents.Subscribe("dota_player_hero_selection_dirty", Run);
    GameEvents.Subscribe("dota_player_update_hero_selection", Run);
    function Tick() { Run(); $.Schedule(0.3, Tick); }
    $.Schedule(0.3, Tick);
})();
