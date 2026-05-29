CustomHeroesPlugin = class({})
_G.CustomHeroesPlugin = CustomHeroesPlugin

-- The set of custom (non-Valve) heroes this mod adds. Add new custom heroes here
-- so the "Custom Heroes" setup toggle governs them all. These MUST also be listed
-- in scripts/npc/herolist.txt (CustomHeroList) or the engine won't let them be
-- picked at all -- availability filtering can only narrow that list, not extend it.
CustomHeroesPlugin.custom_heroes = {
    "npc_dota_hero_flasaro",
}

function CustomHeroesPlugin:Init()
    --print("[CustomHeroesPlugin] found")
end

-- Hide custom heroes from the pick grid. herolist.txt is the master selectable
-- set; availability filtering is a SUBSET of it, so we switch the picker to an
-- explicit set of every NON-custom hero, leaving the custom heroes unavailable.
local function hide_custom_heroes()
    local custom_set = {}
    for _,n in ipairs(CustomHeroesPlugin.custom_heroes) do custom_set[n] = true end

    local herolist = LoadKeyValues('scripts/npc/herolist.txt')
    if herolist == nil or not next(herolist) then return end

    GameRules:SetHideBlacklistedHeroes(true)
    GameRules:GetGameModeEntity():SetPlayerHeroAvailabilityFiltered(true)
    for iPlayer = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayer(iPlayer) then
            for name,_ in pairs(herolist) do
                if not custom_set[name] then
                    local id = DOTAGameManager:GetHeroIDByName(name)
                    -- Skip ids the client doesn't have and the invalid sentinel.
                    if id ~= nil and id > 0 then
                        GameRules:AddHeroToPlayerAvailability(iPlayer, id)
                    end
                end
            end
        end
    end
end

-- This file is require()'d for every plugin regardless of its enabled state, so
-- this listener is ALWAYS registered. That lets us act when the "Custom Heroes"
-- toggle is OFF -- the plugin system would never call a disabled plugin's
-- ApplySettings, but we still need to hide custom heroes in that case.
--
-- Note: PluginSystem:GetAllSetting returns boolean settings as true/false.
ListenToGameEvent("game_rules_state_change", function()
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then return end
    local settings = PluginSystem:GetAllSetting("custom_heroes")
    -- toggle ON (checked) -> custom heroes allowed; herolist already shows them.
    if settings ~= nil and settings.enabled == true then return end
    -- toggle OFF (default) -> hide them.
    hide_custom_heroes()
end, nil)
