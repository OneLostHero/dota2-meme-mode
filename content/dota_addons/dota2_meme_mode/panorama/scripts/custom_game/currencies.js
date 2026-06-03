"use strict";
var plugin_settings = {};
var WindowRoot = $.GetContextPanel().FindChildInLayoutFile("WindowRoot");
// Combined Boost Juice HUD strip (boost juice "red" currency renders here, not as a generic chip).
var BoostStrip = $.GetContextPanel().FindChildInLayoutFile("BoostStrip");
var BoostStripAmount = $.GetContextPanel().FindChildInLayoutFile("BoostStripAmount");
var BoostStripBadge = $.GetContextPanel().FindChildInLayoutFile("BoostStripBadge");
var BoostStripUpgradeBtn = $.GetContextPanel().FindChildInLayoutFile("BoostStripUpgradeBtn");
var BoostStripPotionBtn = $.GetContextPanel().FindChildInLayoutFile("BoostStripPotionBtn");
const STRIP_CURRENCY = "red"; // Boost Juice
var tCurrencies = {};
var iPlayer = Players.GetLocalPlayer();
const this_window_id = "currencies";
const local_team = Players.GetTeam(Players.GetLocalPlayer());
var tCurrencyNumbers = {}
var currency_open;
var menuOpenName = null;   // which currency's converter menu is currently open
var menuSuppress = false;  // brief guard so the closing click doesn't immediately reopen
var openMenuPanel = null;  // the live converter panel, so we can explicitly close it

// Close the open converter menu (used by both click-outside blur AND the
// click-the-chip-again toggle). menuSuppress briefly blocks an immediate reopen.
function CloseCurrencyMenu() {
    if (openMenuPanel) {
        var p = openMenuPanel;
        openMenuPanel = null;
        try { p.DeleteAsync(0); } catch (e) {}
    }
    menuOpenName = null;
    menuSuppress = true;
    $.Schedule(0.18, function () { menuSuppress = false; });
}

function CurrencyShareAmount(tData) {
    if (tData.share == 0) return tData.amount[iPlayer];
    if (tData.share == 1) return tData.amount[Players.GetTeam(iPlayer)];
    if (tData.share == 2) return tData.amount[0];
    return 0;
}

function AddCurrency(sName,tData) {
    if (tData.share == 3)
        return;
    tCurrencies[sName] = tData;

    // Boost Juice ("red") is the combined HUD strip, not a generic chip.
    if (sName === STRIP_CURRENCY && BoostStrip) {
        tCurrencyNumbers[sName] = BoostStripAmount;
        BoostStripAmount.text = CurrencyShareAmount(tData);

        var cnameS = $.Localize("#Currency_" + sName);
        if (cnameS === "#Currency_" + sName) { cnameS = sName; }
        var cdescS = $.Localize("#Currency_" + sName + "_Desc");
        var ctipS = (cdescS === "#Currency_" + sName + "_Desc") ? cnameS : (cnameS + ": " + cdescS);

        if (BoostStripPotionBtn) {
            BoostStripPotionBtn.SetPanelEvent("onmouseover", function () { if (menuOpenName !== sName) $.DispatchEvent("DOTAShowTextTooltip", BoostStripPotionBtn, ctipS); });
            BoostStripPotionBtn.SetPanelEvent("onmouseout", function () { $.DispatchEvent("DOTAHideTextTooltip", BoostStripPotionBtn); });
            if (plugin_settings[sName + "_gold_buy"] && plugin_settings[sName + "_gold_buy"].VALUE > 0) {
                BoostStripPotionBtn.SetPanelEvent("onactivate", function () {
                    CloseUpgradeDrawer(); // clicking Boost Juice dismisses the upgrade drawer
                    if (menuSuppress) return;
                    if (menuOpenName === sName) { CloseCurrencyMenu(); return; } // toggle closed
                    ShowOptionMenu(sName);
                });
            }
        }
        return;
    }

    let CurrencyBox = $.CreatePanel('Panel', WindowRoot, 'CurrencyBox');
    CurrencyBox.BLoadLayoutSnippet("CurrencyBox");
    let CurrencyIcon = CurrencyBox.FindChildInLayoutFile("CurrencyIcon");
    CurrencyIcon.SetHasClass("currency_" + sName,true);
    CurrencyBox.SetHasClass("share_" + tData.share,true);
    CurrencyBox.SetHasClass("currency_box_" + sName,true);
    tCurrencyNumbers[sName] = CurrencyBox.FindChildInLayoutFile("CurrencyAmmount");
    if (tData.share == 0) {
        tCurrencyNumbers[sName].text = tData.amount[iPlayer];
    } else if (tData.share == 1) {
        let iTeam = Players.GetTeam( iPlayer );
        tCurrencyNumbers[sName].text = tData.amount[iTeam];
    } else if (tData.share == 2) {
        tCurrencyNumbers[sName].text = tData.amount[0];
    }
    
    var cname = $.Localize("#Currency_" + sName);
    if (cname === "#Currency_" + sName) { cname = sName; }
    var cdesc = $.Localize("#Currency_" + sName + "_Desc");
    var ctip = (cdesc === "#Currency_" + sName + "_Desc") ? cname : (cname + ": " + cdesc);
    // Don't show the hover tooltip while this currency's menu is open (it would
    // cover the menu that just popped up).
    CurrencyBox.SetPanelEvent("onmouseover", function () { if (menuOpenName !== sName) $.DispatchEvent("DOTAShowTextTooltip", CurrencyBox, ctip); });
    CurrencyBox.SetPanelEvent("onmouseout", function () { $.DispatchEvent("DOTAHideTextTooltip", CurrencyBox); });

    if (plugin_settings[sName + "_gold_buy"].VALUE > 0) {
        CurrencyBox.SetPanelEvent(
            "onactivate",
            function(){
                if (menuSuppress) return;
                if (menuOpenName === sName) { CloseCurrencyMenu(); return; } // toggle closed
                ShowOptionMenu(sName);
            }
        );
    }
}

function ShowOptionMenu(sName) {
    
    let CurrencyActionBox = $.CreatePanel('Panel', $.GetContextPanel(), sName + "_options");
    CurrencyActionBox.BLoadLayoutSnippet("CurrencyActionBox");
    menuOpenName = sName;
    openMenuPanel = CurrencyActionBox;
    $.DispatchEvent("DOTAHideTextTooltip", CurrencyActionBox); // clear the hover tooltip so it doesn't cover the menu
    // No blur-close on purpose: the menu only closes when Boost Juice is clicked
    // again, or when Ability Upgrades (the crest) is clicked. Clicking the map
    // or elsewhere leaves it open.
    var cname2 = $.Localize("#Currency_" + sName);
    if (cname2 === "#Currency_" + sName) { cname2 = sName; }
    var localGold = Players.GetGold(Players.GetLocalPlayer());
    var balAmt = 0;
    var cdata = tCurrencies[sName];
    if (cdata) {
        if (cdata.share == 0) balAmt = cdata.amount[iPlayer];
        else if (cdata.share == 1) balAmt = cdata.amount[Players.GetTeam(iPlayer)];
        else if (cdata.share == 2) balAmt = cdata.amount[0];
    }
    var header = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyActionHeader_' + sName);
    header.AddClass('CurrencyActionHeader');
    header.text = cname2 + ":  " + balAmt + "    Gold: " + localGold;
    var goldPerPoint = 0;
    if (tCurrencies[sName] && tCurrencies[sName].earn_options) {
        for (var ek in tCurrencies[sName].earn_options) {
            var eo = tCurrencies[sName].earn_options[ek];
            if (eo && Number(eo.earn) > 0) { goldPerPoint = Number(eo.cost) / Number(eo.earn); break; }
        }
    }
    if (goldPerPoint > 0) {
        var rateLabel = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyActionRate_' + sName);
        rateLabel.AddClass('CurrencyActionRate');
        rateLabel.text = Math.round(goldPerPoint) + " gold = 1 " + cname2;
    }
    // Help: cost-per-upgrade + how to earn + warning (Boost Juice menu).
    // Import the real upgrade-point cost from the boosted plugin's settings.
    var pickCost = 0;
    var bset = CustomNetTables.GetTableValue("plugin_settings", "boosted");
    if (bset && bset.cost && bset.cost.VALUE != undefined) { pickCost = Number(bset.cost.VALUE); }
    if (!(pickCost > 0) && tCurrencies[sName] && tCurrencies[sName].spend_options) {
        for (var sk in tCurrencies[sName].spend_options) {
            var so = tCurrencies[sName].spend_options[sk];
            if (so && Number(so.cost) > 0) { pickCost = Number(so.cost); break; }
        }
    }
    if (pickCost > 0) {
        var helpCost = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyHelpCost_' + sName);
        helpCost.AddClass('CurrencyHelpCost');
        helpCost.text = pickCost + " " + cname2 + " = 1 upgrade point" + (goldPerPoint > 0 ? ("  (~" + Math.round(pickCost * goldPerPoint) + " gold)") : "");
    }
    // "?" help: how to earn this currency + how much each source gives, pulled
    // live from the currencies plugin settings so it tracks any config change.
    var cset = CustomNetTables.GetTableValue("plugin_settings", "currencies") || {};
    function settingNum(k){ return (cset[k] && cset[k].VALUE != undefined) ? Number(cset[k].VALUE) : 0; }
    function settingStr(k){ return (cset[k] && cset[k].VALUE != undefined) ? String(cset[k].VALUE) : ""; }
    var earnSources = [
        ["hero_kill",       "Hero kill"],
        ["unit_kill",       "Last hit / unit kill"],
        ["tower_kill",      "Tower kill"],
        ["roshan_kill",     "Roshan kill"],
        ["tormentor_kill",  "Tormentor kill"],
        ["observer_plant",  "Place a ward"],
        ["observer_kill",   "Destroy a ward"],
        ["lamp_capture",    "Capture a lamp"],
        ["outpost_capture", "Capture an outpost"],
        ["timed",           "Passive income (per tick)"]
    ];
    var earnHeader = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyEarnHeader_' + sName);
    earnHeader.AddClass('CurrencyEarnHeader');
    earnHeader.text = "?  How to earn " + cname2;
    var anyEarn = false;
    for (var si = 0; si < earnSources.length; si++) {
        var src = earnSources[si][0], label = earnSources[si][1];
        if (settingStr(src + "_reward_currency") !== sName) continue;
        var amt = settingNum(src + "_reward_amount");
        if (!(amt > 0)) continue;
        anyEarn = true;
        var lineEarn = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyEarnLine_' + src);
        lineEarn.AddClass('CurrencyEarnLine');
        lineEarn.text = label + ":  +" + amt + " " + cname2;
    }
    if (goldPerPoint > 0) {
        anyEarn = true;
        var lineConv = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyEarnLine_convert');
        lineConv.AddClass('CurrencyEarnLine');
        lineConv.text = "Convert gold (below):  " + Math.round(goldPerPoint) + " gold = 1 " + cname2;
    }
    if (!anyEarn) {
        var lineNone = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyEarnLine_none');
        lineNone.AddClass('CurrencyEarnLine');
        lineNone.text = "Earn in combat or convert gold below.";
    }
    var helpWarn = $.CreatePanel('Label', CurrencyActionBox, 'CurrencyHelpWarn_' + sName);
    helpWarn.AddClass('CurrencyHelpWarn');
    helpWarn.text = "WARNING: Upgrades are RANDOM. They can buff OR nerf any ability, and may even break your hero.";
    let spend_count = 0;
    for (const key in tCurrencies[sName].spend_options) {
        const option = tCurrencies[sName].spend_options[key];
        $.Msg(option);
        if (option.autobuy == false) {
            spend_count = 99;
        }
        if (option.team == 1 || local_team == option.team) {
            spend_count++;
        }
    }
    if (spend_count > 1) {
        for (const key in tCurrencies[sName].spend_options) {
            const option = tCurrencies[sName].spend_options[key];
            let CurrencyAction = $.CreatePanel('Panel', CurrencyActionBox, sName + "_options");
            CurrencyAction.BLoadLayoutSnippet("CurrencyAction");
            CurrencyAction.FindChildInLayoutFile("CurrencyLabel").text = $.Localize("#SpendOption_" + option.plugin_name + "_" + option.option_name);
            CurrencyAction.FindChildInLayoutFile("CurrencyCost").text = option.cost;
            if (goldPerPoint > 0) {
                CurrencyAction.FindChildInLayoutFile("CurrencyCost").text = option.cost + "  (~" + Math.round(Number(option.cost) * goldPerPoint) + "g)";
            }
            CurrencyAction.SetPanelEvent(
                "onactivate", 
                function(){
                    GameEvents.SendCustomGameEventToServer("currency_spend",{
                        "currency": sName,
                        "option": option.fn
                    });
                }
            );
        }
    }
    for (const key in tCurrencies[sName].earn_options) {
        const option = tCurrencies[sName].earn_options[key];
        let CurrencyEarnAction = $.CreatePanel('Panel', CurrencyActionBox, sName + "_options");
        CurrencyEarnAction.BLoadLayoutSnippet("CurrencyEarnAction");
        CurrencyEarnAction.FindChildInLayoutFile("CurrencyCost").text = option.cost;
        CurrencyEarnAction.FindChildInLayoutFile("CurrencyEarn").text = option.earn;
        if (localGold < Number(option.cost)) {
            CurrencyEarnAction.AddClass('unaffordable');
        }
        CurrencyEarnAction.SetPanelEvent(
            "onactivate", 
            function(){
                GameEvents.SendCustomGameEventToServer("currency_earn",{
                    "currency": sName,
                    "option": option.fn
                });
            }
        );
    }
}



function tCurrenciesUpdate( table_name, currency, table) {
    tCurrencies[currency] = table;
    if (tCurrencies[currency].share == 0) {
        tCurrencyNumbers[currency].text = tCurrencies[currency].amount[iPlayer];
    } else if (tCurrencies[currency].share == 1) {
        let iTeam = Players.GetTeam( iPlayer );
        tCurrencyNumbers[currency].text = tCurrencies[currency].amount[iTeam];
    } else if (tCurrencies[currency].share == 2) {
        tCurrencyNumbers[currency].text = tCurrencies[currency].amount[0];
    }
    $.Msg(tCurrencies);
}

function Cleanup() {
    WindowRoot.RemoveAndDeleteChildren();
}

// Mirror upgrade.js: ride just above the bottom-left quickbuy/shop cluster so
// the Boost Juice bar rises together with the upgrade icon as quickbuy fills.
function GetDotaHud() {
    var panel = $.GetContextPanel();
    while (panel && panel.id !== 'Hud') { panel = panel.GetParent(); }
    return panel;
}
// Single-context reflow. The strip's bottom tracks the TOP of the quickbuy
// cluster (which grows upward as items are queued), so the whole strip rides
// up together — no second context to drift apart.
var HUD_BAR_BASE_MARGIN = 34; // fallback only (HUD not found / bad numbers)
var HUD_BAR_OFFSET = 4;       // small gap so the strip nearly-but-not-quite touches the quickbuy bar
var _hudLogTick = 0;
function ComputeHudBarMargin() {
    var hud = GetDotaHud();
    if (!hud) return HUD_BAR_BASE_MARGIN;
    var winH = hud.actuallayoutheight;
    if (!isFinite(winH) || winH <= 0) return HUD_BAR_BASE_MARGIN;
    var qb = hud.FindChildTraverse("quickbuy");
    var slb = hud.FindChildTraverse("shop_launcher_block");
    if ((_hudLogTick++ % 10) === 0) {
        function info(p) {
            if (!p) return "none";
            var y = "?", h = "?";
            try { y = Math.round(p.GetPositionWithinWindow().y); } catch (e) {}
            try { h = Math.round(p.actuallayoutheight); } catch (e) {}
            return "top=" + y + " h=" + h;
        }
        function wid(p) { if (!p) return "?"; try { return Math.round(p.actuallayoutwidth); } catch (e) { return "?"; } }
        $.Msg("HUDPOS(strip): winH=" + Math.round(winH) + " | quickbuy " + info(qb) + " w=" + wid(qb) + " | shop_launcher_block " + info(slb) + " w=" + wid(slb));
    }
    var cluster = qb || slb;
    if (!cluster) return HUD_BAR_BASE_MARGIN;
    var top;
    try { top = cluster.GetPositionWithinWindow().y; } catch (e) { return HUD_BAR_BASE_MARGIN; }
    if (!isFinite(top) || top <= 0) return HUD_BAR_BASE_MARGIN;
    var mb = (winH - top) + HUD_BAR_OFFSET;
    if (mb < HUD_BAR_BASE_MARGIN) mb = HUD_BAR_BASE_MARGIN;
    var maxMB = winH * 0.45;          // safety clamp so a bad reading can't fling the strip up the screen
    if (mb > maxMB) mb = maxMB;
    return mb;
}
var _lastMB = -1, _lastW = -1;
function RepositionBar() {
    $.Schedule(0.1, RepositionBar);
    var mb = Math.round(ComputeHudBarMargin());
    if (mb !== _lastMB) { _lastMB = mb; $.GetContextPanel().style.marginBottom = mb + "px"; } // only on change -> smooth transition
    // Stretch the strip to the width of the bottom-left gold/quickbuy module so it lines up flush.
    if (BoostStrip) {
        var hud = GetDotaHud();
        var blk = hud && (hud.FindChildTraverse("shop_launcher_block") || hud.FindChildTraverse("quickbuy"));
        if (blk) {
            var w = Math.round(blk.actuallayoutwidth);
            if (w > 40 && w !== _lastW) { _lastW = w; BoostStrip.style.width = w + "px"; }
        }
    }
}

// Toggle the upgrade drawer that lives in the (separate) upgrade.xml HUD context.
// Both are children of "Hud", so a traverse finds it; we only flip a CSS class
// (no cross-context function call), which is robust regardless of mount order.
function ToggleUpgradeDrawer() {
    var hud = GetDotaHud();
    if (!hud) return;
    var drawer = hud.FindChildTraverse("UpgradeDrawer");
    if (drawer) { drawer.SetHasClass("hidden", !drawer.BHasClass("hidden")); }
}
function CloseUpgradeDrawer() {
    var hud = GetDotaHud();
    if (!hud) return;
    var drawer = hud.FindChildTraverse("UpgradeDrawer");
    if (drawer) { drawer.SetHasClass("hidden", true); }
}

// While the shop is open it should own the top-left space, so hide the strip
// (and dismiss the menu/drawer) instead of letting our icons sit in front of it.
var _shopWasOpen = false;
function UpdateShopCover() {
    $.Schedule(0.2, UpdateShopCover);
    var shopOpen = false;
    try { shopOpen = Game.IsShopOpen(); } catch (e) { shopOpen = false; }
    if (shopOpen === _shopWasOpen) return;
    _shopWasOpen = shopOpen;
    if (BoostStrip) BoostStrip.SetHasClass("hidden", shopOpen);
    if (shopOpen) {
        if (openMenuPanel) CloseCurrencyMenu();
        CloseUpgradeDrawer();
    }
}

// Queued upgrade-pick count for the crest badge, read from the player_booster net table.
function UpdateStripBadge() {
    if (!BoostStripBadge) return;
    var n = 0;
    var pb = CustomNetTables.GetTableValue("player_booster", iPlayer + "d");
    if (pb && pb.boosters !== undefined) { n = Number(pb.boosters) || 0; }
    BoostStripBadge.text = String(n);
    BoostStripBadge.SetHasClass("hidden", n <= 0);
}


(function () {
    
    Cleanup();
    plugin_settings = CustomNetTables.GetTableValue( "plugin_settings", this_window_id );
    if (plugin_settings.enabled.VALUE == 0) {
        WindowRoot.SetHasClass("hidden",true);
    } else {
        tCurrencies = CustomNetTables.GetAllTableValues( "currencies" );
        for (const key in tCurrencies) {
            AddCurrency(tCurrencies[key].key,tCurrencies[key].value);
        }
        CustomNetTables.SubscribeNetTableListener( "currencies" , tCurrenciesUpdate );

        // Strip's crest button toggles the upgrade drawer; potion is wired in AddCurrency.
        if (BoostStripUpgradeBtn) {
            BoostStripUpgradeBtn.SetPanelEvent("onactivate", function () {
                if (openMenuPanel) CloseCurrencyMenu(); // clicking Ability Upgrades dismisses the Boost Juice menu
                ToggleUpgradeDrawer();
            });
            BoostStripUpgradeBtn.SetPanelEvent("onmouseover", function () { $.DispatchEvent("DOTAShowTextTooltip", BoostStripUpgradeBtn, "Toggle Ability Upgrades"); });
            BoostStripUpgradeBtn.SetPanelEvent("onmouseout", function () { $.DispatchEvent("DOTAHideTextTooltip", BoostStripUpgradeBtn); });
        }
        UpdateStripBadge();
        CustomNetTables.SubscribeNetTableListener("player_booster", function (t, k) { if (k === iPlayer + "d") UpdateStripBadge(); });

        // Fixed top-left placement (under K/D/A) via CSS — no quickbuy-ride needed up here.
        // RepositionBar()/width-match are left defined but unused.
        UpdateShopCover(); // hide the strip while the shop is open
    }
    if (Game.IsHUDFlipped()) {
        $.GetContextPanel().SetHasClass("flipped",true);
        WindowRoot.SetHasClass("map_left_window_root",true);
        WindowRoot.SetHasClass("map_right_window_root",false);
    } else {
        $.GetContextPanel().SetHasClass("flipped",false);
        WindowRoot.SetHasClass("map_left_window_root",false);
        WindowRoot.SetHasClass("map_right_window_root",true);
    }
})();