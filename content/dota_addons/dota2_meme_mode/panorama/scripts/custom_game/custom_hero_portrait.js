"use strict";
// Custom hero portrait fix + on-screen diagnostic.
// The self-test proved the element loads and image-by-path works; this readout tells
// us which pick-screen panels the script can actually reach.

var CUSTOM_HEROES = {
    "npc_dota_hero_flasaro": true,
    "npc_dota_hero_onelosthero": true,
};
function IsCustomHero(name) { return name != null && name !== "" && CUSTOM_HEROES[name] === true; }
function SelectionImg(name) { return 'url("file://{images}/heroes/selection/' + name + '.png")'; }

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
function Has(root, id) { try { return !!root.FindChildTraverse(id); } catch (e) { return false; } }

function CountHeronames(panel, depth, acc) {
    if (!panel || depth > 80) return;
    var h = null; try { h = panel.heroname; } catch (e) {}
    if (h) { acc.total++; if (IsCustomHero(h)) { acc.custom++; if (acc.firstCustomId === "") acc.firstCustomId = panel.id + "(" + panel.paneltype + ")"; } }
    var kids = null; try { kids = panel.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) CountHeronames(kids[i], depth + 1, acc); }
}

function FindRenderPanel(root, depth) {
    if (!root || depth > 12) return null;
    var pt = null; try { pt = root.paneltype; } catch (e) {}
    if (pt === "DOTAScenePanel" || pt === "DOTAHeroMovie" || pt === "DOTAPortrait") return root;
    var kids = null; try { kids = root.Children(); } catch (e) {}
    if (kids) { for (var i = 0; i < kids.length; i++) { var r = FindRenderPanel(kids[i], depth + 1); if (r) return r; } }
    return null;
}

function Diag() {
    var lbl = $.GetContextPanel().FindChildTraverse("ChpDiag");
    if (!lbl) return;
    try {
        var root = Root();
        var up = 0; var p = $.GetContextPanel(); while (p && p.GetParent && p.GetParent() && up < 300) { p = p.GetParent(); up++; }
        var inspect = null; try { inspect = root.FindChildTraverse("HeroInspectInfo"); } catch (e) {}
        var acc = { total: 0, custom: 0, firstCustomId: "" };
        CountHeronames(root, 0, acc);
        var render = inspect ? FindRenderPanel(inspect, 0) : null;
        var renderType = render ? render.paneltype : "none";
        lbl.text = "chp up=" + up + " rootId=" + (root ? root.id : "?")
            + "\nHud=" + Has(root, "Hud") + " PreGame=" + Has(root, "PreGame")
            + " HeroPickScreen=" + Has(root, "HeroPickScreen")
            + " HeroInspectInfo=" + (!!inspect) + " HeroGrid=" + Has(root, "HeroGrid")
            + "\nheronamePanels=" + acc.total + " custom=" + acc.custom + " first=" + acc.firstCustomId
            + "\ninspectRenderPanel=" + renderType + " sel=" + LocalSelection();
    } catch (e) {
        lbl.text = "chp ERROR: " + e;
    }
}

(function () {
    function Tick() { Diag(); $.Schedule(0.5, Tick); }
    $.Schedule(0.5, Tick);
})();
