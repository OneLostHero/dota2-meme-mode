
var Upgrades = $.GetContextPanel().FindChildInLayoutFile("Upgrades");
var sending = false;
var bWaiting = true;
var tCurrent;

const this_plugin_id = "boosted";
var plugin_settings = {};
const local_team = Players.GetTeam(Players.GetLocalPlayer());

var QueuedUpgradesText = $.GetContextPanel().FindChildInLayoutFile("QueuedUpgradesText");
var Drawer = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawer");
var DrawerQueued = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerQueued");
var DrawerEmpty = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerEmpty");
var ToggleFloat = $.GetContextPanel().FindChildInLayoutFile("UpgradeToggleFloat");
var ToggleBadge = $.GetContextPanel().FindChildInLayoutFile("UpgradeToggleBadge");

function UpdateToggleBadge() {
    if (!ToggleBadge) return;
    var n = 0;
    try { n = Number(QueuedUpgradesText.text) || 0; } catch (e) { n = 0; }
    ToggleBadge.text = String(n);
    ToggleBadge.SetHasClass("hidden", n <= 0);
}

function UpdateEmptyState() {
    var hasRows = Upgrades.Children().length > 0;
    DrawerEmpty.SetHasClass("hidden", hasRows);
}

function UpgradeOptionNew(data) {
    var upgradePanel = $.CreatePanel('Panel', Upgrades, '');
    upgradePanel.BLoadLayoutSnippet("UpgradeOption");
    if (data.rarity == 2) {
        upgradePanel.SetHasClass("rare",true);
    }
    if (data.rarity == 3) {
        upgradePanel.SetHasClass("ultra",true);
    }
    if (data.rarity == 4) {
        upgradePanel.SetHasClass("unique",true);
    }

    if (data.ability.includes("item_")) {
        var UpgradeOptionImage = upgradePanel.FindChildTraverse("UpgradeOptionImage");
        UpgradeOptionImage.visible = false
        var UpgradeOptionImageItem = upgradePanel.FindChildTraverse("UpgradeOptionImageItem");
        UpgradeOptionImageItem.itemname = data.ability;
    } else {
        var UpgradeOptionImage = upgradePanel.FindChildTraverse("UpgradeOptionImage");
        UpgradeOptionImage.abilityname = data.ability;
        var UpgradeOptionImageItem = upgradePanel.FindChildTraverse("UpgradeOptionImageItem");
        UpgradeOptionImageItem.visible = false
    }
    var UpgradeOptionLabel = upgradePanel.FindChildTraverse("UpgradeOptionLabel");
    var UpgradeOptionAbilityName = upgradePanel.FindChildTraverse("UpgradeOptionAbilityName");
    var nameLoc = data.ability.includes("item_")
        ? $.Localize("#DOTA_Tooltip_" + data.ability)
        : $.Localize("#DOTA_Tooltip_Ability_" + data.ability);
    // Fall back to a de-prefixed, readable raw name if no localization exists.
    if (nameLoc.indexOf("#DOTA_Tooltip") === 0) {
        nameLoc = data.ability.replace("item_", "").replace(/_/g, " ");
    }
    UpgradeOptionAbilityName.text = nameLoc;

    var reportBtn = upgradePanel.FindChildTraverse("AbilityChangeReport");
    reportBtn.SetPanelEvent('onactivate', function () {
        GameEvents.SendCustomGameEventToServer( "upgrade_report", {ab: data.ability,kv: data.key});
    } );
    reportBtn.SetPanelEvent('onmouseover', function () { $.DispatchEvent("DOTAShowTextTooltip", reportBtn, "Report this upgrade (flag as broken/OP)"); });
    reportBtn.SetPanelEvent('onmouseout', function () { $.DispatchEvent("DOTAHideTextTooltip", reportBtn); });

    if (data.rarity == 4) {
        //uniques
        UpgradeOptionLabel.text = $.Localize("#Unique_" + data.key);
        upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onactivate', function () {
            pickoption( data.ability, data.key, 1, upgradePanel,data.rarity );
        } );
        upgradePanel.FindChildTraverse( "OptionButtonMinus" ).visible = false;
        var OptionButtonPlusText = upgradePanel.FindChildTraverse("OptionButtonPlusText");
        OptionButtonPlusText.text = "Select";
        UpgradeOptionLabel.SetPanelEvent( 'onmouseover', function () {
            $.DispatchEvent("DOTAShowTextTooltip", UpgradeOptionLabel, $.Localize("#Unique_" + data.key + "_Desc"));
        } );
        UpgradeOptionLabel.SetPanelEvent( 'onmouseout', function () {
            $.DispatchEvent("DOTAHideTextTooltip", UpgradeOptionLabel);
        } );

        ///normal stuff
    } else {
        /* if (data.key == "value") {
            UpgradeOptionLabel.text = $.Localize("#DOTA_Tooltip_Ability_" + data.ability);
        }
        else */
        if ($.Localize("#DOTA_Dev_Tooltip_Ability_" + data.ability + "_" + data.key) == "#DOTA_Dev_Tooltip_Ability_" + data.ability + "_" + data.key) {
            if ($.Localize("#DOTA_Tooltip_Ability_" + data.ability + "_" + data.key) == "#DOTA_Tooltip_Ability_" + data.ability + "_" + data.key) {
                UpgradeOptionLabel.text = data.key;
            } else {
                UpgradeOptionLabel.text = $.Localize("#DOTA_Tooltip_Ability_" + data.ability + "_" + data.key);
            }
        } else {
            UpgradeOptionLabel.text = $.Localize("#DOTA_Dev_Tooltip_Ability_" + data.ability + "_" + data.key)
        }
        let current_real = data.current_mult * data.current;
        let upgrade_real = data.current * data.upgrade * 0.01;
        let downgrade_real = data.current * data.downgrade * 0.01;
        UpgradeOptionLabel.SetPanelEvent( 'onmouseover', function () {
            $.DispatchEvent("DOTAShowTextTooltip", UpgradeOptionLabel, data.key + ": " + current_real.toFixed(2));
        } );
        UpgradeOptionLabel.SetPanelEvent( 'onmouseout', function () {
            $.DispatchEvent("DOTAHideTextTooltip", UpgradeOptionLabel);
        } );
        var OptionButtonPlusText = upgradePanel.FindChildTraverse("OptionButtonPlusText");
        var OptionButtonMinusText = upgradePanel.FindChildTraverse("OptionButtonMinusText");
        OptionButtonPlusText.text = "+" + Math.round(data.upgrade) + "%";
        OptionButtonMinusText.text = "-" + Math.round(data.downgrade) + "%";
        if (Math.round(data.current_mult*100) == Math.round(data.upgrade)) {
            //upgradePanel.FindChildTraverse( "OptionButtonPlusText" ).SetHasClass("DullUpgrade",true);
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetHasClass("DullUpgrade",true);
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onmouseover', function () {
                $.DispatchEvent("DOTAShowTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonPlus" ), "Maxed");
            } );
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onmouseout', function () {
                $.DispatchEvent("DOTAHideTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonPlus" ));
            } );
        } else {
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetHasClass("OptionButtonPlus",true);
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onmouseover', function () {
                $.DispatchEvent("DOTAShowTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonPlus" ), current_real.toFixed(2) + " => " + upgrade_real.toFixed(2));
            } );
            upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onmouseout', function () {
                $.DispatchEvent("DOTAHideTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonPlus" ));
            } );
        }
        if (Math.round(data.current_mult*100) == Math.round(data.downgrade)) {
            //upgradePanel.FindChildTraverse( "OptionButtonMinusText" ).SetHasClass("DullUpgrade",true);
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetHasClass("DullUpgrade",true);
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetPanelEvent( 'onmouseover', function () {
                $.DispatchEvent("DOTAShowTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonMinus" ), "Maxed");
            } );
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetPanelEvent( 'onmouseout', function () {
                $.DispatchEvent("DOTAHideTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonMinus" ));
            } );
        } else {
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetHasClass("OptionButtonMinus",true);
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetPanelEvent( 'onmouseover', function () {
                $.DispatchEvent("DOTAShowTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonMinus" ), current_real.toFixed(2) + " => " + downgrade_real.toFixed(2));
            } );
            upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetPanelEvent( 'onmouseout', function () {
                $.DispatchEvent("DOTAHideTextTooltip", upgradePanel.FindChildTraverse( "OptionButtonMinus" ));
            } );
        }
        upgradePanel.FindChildTraverse( "OptionButtonPlus" ).SetPanelEvent( 'onactivate', function () {
            pickoption( data.id, 1, upgradePanel);

        } );
        upgradePanel.FindChildTraverse( "OptionButtonMinus" ).SetPanelEvent( 'onactivate', function () {
            pickoption( data.id, 0, upgradePanel);
        } );

        if (data.allow_ban) {
            upgradePanel.FindChildTraverse( "OptionButtonBan" ).SetPanelEvent( 'onactivate', function () {
                pickoption( data.id, 2, upgradePanel);
            } );
            var banBtn = upgradePanel.FindChildTraverse("OptionButtonBan");
            banBtn.SetPanelEvent('onmouseover', function () { $.DispatchEvent("DOTAShowTextTooltip", banBtn, "Never show this upgrade again"); });
            banBtn.SetPanelEvent('onmouseout', function () { $.DispatchEvent("DOTAHideTextTooltip", banBtn); });
        } else {
            upgradePanel.FindChildTraverse( "OptionButtonBan" ).visible = false;
        }

    }
}

function GetSpecial(ability,key) {
    let hero_ent = Players.GetPlayerHeroEntityIndex( Players.GetLocalPlayer() );
    let ablity = Entities.GetAbilityByName( hero_ent, ability );
    let value = Abilities.GetSpecialValueFor( ablity, key );
    return value;
}

function UpgradeOptionsNew(table,tableKey,data) {
    if (tableKey == Players.GetLocalPlayer() + "d") {
		$.Schedule( 0.2, function() {
            if (sending) {
                UpgradeOptionsNew(table,tableKey,data);
            } else {
                Upgrades.RemoveAndDeleteChildren();
                if (typeof(data) == "object") {

                    if (Object.keys(data).length > 1) {
                        bWaiting = false;
                        tCurrent = data;
                        for (let key in data) {
                            if (key != "boosters") {
                                UpgradeOptionNew(data[key]);
                            } else {
                                QueuedUpgradesText.text = data[key];
                                UpdateToggleBadge();
                            }
                        }
                        UpdateEmptyState();
                        UpdateToggleBadge();
                    } else {
                        bWaiting = true;
                        tCurrent = undefined;
                        UpdateEmptyState();
                        UpdateToggleBadge();
                    }
                }
            }
        } );
    }
}

function pickoption(id,plus,panel) {
    var pls_b = plus;
    Upgrades.RemoveAndDeleteChildren();
    if (!sending) {
        sending = true;
        $.Schedule( 0.2, function() {
            sending = false;
            bWaiting = true;
            tCurrent = undefined;
            GameEvents.SendCustomGameEventToServer( "upgrade_hero", {
                plus: pls_b,
                id: id
            })});
    }

}


function boost_player_recheck() {
    $.Schedule( 10, function() {
        boost_player_recheck();
    });
    let children = Upgrades.Children();
    if (!bWaiting) {
        if (children < 1) {
            ForceRecreate();
        }
    }
}

function ForceRecreate() {
    let kvstuff = CustomNetTables.GetTableValue( "player_booster", Players.GetLocalPlayer() + "d" );
    UpgradeOptionsNew("player_booster",Players.GetLocalPlayer() + "d",kvstuff);
}

function GetDotaHud() {
    var panel = $.GetContextPanel();
    while (panel && panel.id !== 'Hud') { panel = panel.GetParent(); }
    return panel;
}
function FindDotaHudElement(id) {
    var hud = GetDotaHud();
    return hud ? hud.FindChildTraverse(id) : null;
}
// Keep our HUD bar riding just above the bottom-left quickbuy/shop cluster.
// The cluster (id "quickbuy" inside "shop_launcher_block") grows UPWARD as the
// player quickbuys items, so we track its top edge each tick and set our
// bottom-margin to (screen height - cluster top + gap). currencies.js mirrors
// this exact math so the upgrade icon and Boost Juice bar rise together.
var HUD_BAR_BASE_MARGIN = 40; // resting height above screen bottom (empty quickbuy)
var HUD_BAR_OFFSET = 0;       // cluster bottom = clusterTop - OFFSET (tune once we have live numbers)
var _hudLogTick = 0;
function ComputeHudBarMargin() {
    var hud = GetDotaHud();
    if (!hud) return HUD_BAR_BASE_MARGIN;
    var winH = hud.actuallayoutheight;
    if (!isFinite(winH) || winH <= 0) return HUD_BAR_BASE_MARGIN;
    var qb = hud.FindChildTraverse("quickbuy");
    var slb = hud.FindChildTraverse("shop_launcher_block");
    // Throttled diagnostic (~once/sec) so we can lock the right reference + offset.
    if ((_hudLogTick++ % 10) === 0) {
        function info(p) {
            if (!p) return "none";
            var y = "?", h = "?";
            try { y = Math.round(p.GetPositionWithinWindow().y); } catch (e) {}
            try { h = Math.round(p.actuallayoutheight); } catch (e) {}
            return "top=" + y + " h=" + h;
        }
        $.Msg("HUDPOS: winH=" + Math.round(winH) + " | quickbuy " + info(qb) + " | shop_launcher_block " + info(slb));
    }
    var cluster = qb || slb;
    if (!cluster) return HUD_BAR_BASE_MARGIN;
    var top;
    try { top = cluster.GetPositionWithinWindow().y; } catch (e) { return HUD_BAR_BASE_MARGIN; }
    if (!isFinite(top) || top <= 0) return HUD_BAR_BASE_MARGIN;
    var mb = (winH - top) + HUD_BAR_OFFSET;
    return mb > HUD_BAR_BASE_MARGIN ? mb : HUD_BAR_BASE_MARGIN;
}
function RepositionBar() {
    $.Schedule(0.1, RepositionBar);
    if (!ToggleFloat) return;
    ToggleFloat.style.marginBottom = Math.round(ComputeHudBarMargin()) + "px";
}

(function init() {
    plugin_settings = CustomNetTables.GetTableValue( "plugin_settings", this_plugin_id );


    let local_disable = plugin_settings.enabled.VALUE == 0;

    if (!local_disable && plugin_settings.core_apply_team.VALUE != 0 && plugin_settings.core_apply_team.VALUE != local_team) {
        local_disable = true;
    }

    if (local_disable) {
        $.GetContextPanel().SetHasClass("hidden",true);
    } else {
        //GameEvents.Subscribe( "upgrade_option", UpgradeOptionNew);
        CustomNetTables.SubscribeNetTableListener("player_booster",UpgradeOptionsNew);
        let kvstuff = CustomNetTables.GetTableValue( "player_booster", Players.GetLocalPlayer() + "d" );
        UpgradeOptionsNew("player_booster",Players.GetLocalPlayer() + "d",kvstuff);
        //GameEvents.Subscribe( "boost_player_recheck", KeepitReal );
        boost_player_recheck();

        if (ToggleFloat) {
            ToggleFloat.SetPanelEvent('onactivate', function () { Drawer.SetHasClass("hidden", !Drawer.BHasClass("hidden")); });
            ToggleFloat.SetPanelEvent('onmouseover', function () { $.DispatchEvent("DOTAShowTextTooltip", ToggleFloat, "Toggle Ability Upgrades"); });
            ToggleFloat.SetPanelEvent('onmouseout', function () { $.DispatchEvent("DOTAHideTextTooltip", ToggleFloat); });
        }
        // Fixed placement (CSS margin-bottom). The dynamic quickbuy-ride was
        // unreliable across the two UI contexts and split the cluster apart.
        UpdateToggleBadge();

        UpdateEmptyState();

        var costLabel = $.GetContextPanel().FindChildInLayoutFile("UpgradeDrawerCost");
        if (costLabel) {
            if (plugin_settings && plugin_settings.cost && plugin_settings.cost.VALUE != undefined) {
                costLabel.text = plugin_settings.cost.VALUE + " Boost Juice / pick";
            } else {
                costLabel.text = "Spend Boost Juice to roll picks";
            }
        }

        DrawerQueued.SetPanelEvent('onmouseover', function () {
            $.DispatchEvent("DOTAShowTextTooltip", DrawerQueued, $.Localize("#Boosted_queue"));
        });
        DrawerQueued.SetPanelEvent('onmouseout', function () {
            $.DispatchEvent("DOTAHideTextTooltip", DrawerQueued);
        });
    }
})();


