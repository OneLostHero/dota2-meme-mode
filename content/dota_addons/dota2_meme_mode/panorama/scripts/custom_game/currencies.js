"use strict";
var plugin_settings = {};
var WindowRoot = $.GetContextPanel().FindChildInLayoutFile("WindowRoot");
var tCurrencies = {};
var iPlayer = Players.GetLocalPlayer();
const this_window_id = "currencies";
const local_team = Players.GetTeam(Players.GetLocalPlayer());
var tCurrencyNumbers = {}
var currency_open;

function AddCurrency(sName,tData) {
    if (tData.share == 3)
        return;
    tCurrencies[sName] = tData;
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
    CurrencyBox.SetPanelEvent("onmouseover", function () { $.DispatchEvent("DOTAShowTextTooltip", CurrencyBox, ctip); });
    CurrencyBox.SetPanelEvent("onmouseout", function () { $.DispatchEvent("DOTAHideTextTooltip", CurrencyBox); });

    if (plugin_settings[sName + "_gold_buy"].VALUE > 0) {
        CurrencyBox.SetPanelEvent(
            "onactivate",
            function(){
                ShowOptionMenu(sName);
            }
        );
    }
}

function ShowOptionMenu(sName) {
    
    let CurrencyActionBox = $.CreatePanel('Panel', $.GetContextPanel(), sName + "_options");
    CurrencyActionBox.BLoadLayoutSnippet("CurrencyActionBox");
    CurrencyActionBox.SetAcceptsFocus(true)
    CurrencyActionBox.SetFocus();
    CurrencyActionBox.SetPanelEvent(
        "onblur",
        function(){
            CurrencyActionBox.DeleteAsync(0);
        }
    );
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