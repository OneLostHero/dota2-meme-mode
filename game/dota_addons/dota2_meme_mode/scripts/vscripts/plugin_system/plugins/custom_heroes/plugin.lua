CustomHeroesPlugin = class({})
_G.CustomHeroesPlugin = CustomHeroesPlugin

-- The set of custom (non-Valve) heroes this mod adds. Add new custom heroes here
-- so the "Custom Heroes" setup toggle governs them all.
CustomHeroesPlugin.custom_heroes = {
    "npc_dota_hero_flasaro",
}

function CustomHeroesPlugin:Init()
    --print("[CustomHeroesPlugin] found")
end

-- IMPORTANT: the plugin system only calls ApplySettings when this plugin is
-- ENABLED in setup (it gates StateRegistrations on enabled == 1). That is exactly
-- what we want here:
--
--   toggle OFF (default) -> ApplySettings never runs. herolist.txt deliberately
--                           omits the custom heroes, so the default pick grid is
--                           standard heroes only and the custom heroes are hidden.
--   toggle ON            -> ApplySettings runs and switches the picker to an
--                           explicit availability set of EVERY standard hero plus
--                           this mod's custom heroes, making the custom heroes
--                           pickable alongside everyone else.
function CustomHeroesPlugin:ApplySettings()
    CustomHeroesPlugin.settings = PluginSystem:GetAllSetting("custom_heroes")
    -- Defensive: should only ever be reached when enabled, but guard anyway.
    if CustomHeroesPlugin.settings == nil or CustomHeroesPlugin.settings.enabled ~= 1 then
        return
    end

    -- Build the allowed set: every hero in herolist.txt (the standard pick grid,
    -- root "CustomHeroList") plus the custom heroes. LoadKeyValues returns the
    -- inner table: { npc_dota_hero_x = "1", ... }.
    local names = {}
    local herolist = LoadKeyValues('scripts/npc/herolist.txt')
    if herolist ~= nil then
        for name,_ in pairs(herolist) do names[name] = true end
    end
    for _,n in ipairs(CustomHeroesPlugin.custom_heroes) do names[n] = true end

    GameRules:SetHideBlacklistedHeroes(true)
    GameRules:GetGameModeEntity():SetPlayerHeroAvailabilityFiltered(true)
    for iPlayer = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayer(iPlayer) then
            for name,_ in pairs(names) do
                local id = DOTAGameManager:GetHeroIDByName(name)
                -- Skip ids the client doesn't have and the invalid sentinel.
                if id ~= nil and id > 0 then
                    GameRules:AddHeroToPlayerAvailability(iPlayer, id)
                end
            end
        end
    end
end
