CustomHeroesPlugin = class({})
_G.CustomHeroesPlugin = CustomHeroesPlugin

-- The set of custom (non-Valve) heroes this mod adds. Add new custom heroes here
-- so the "Custom Heroes" setup toggle governs them all. These MUST also be listed
-- in scripts/npc/herolist.txt (CustomHeroList) or the engine won't let them be
-- picked at all -- availability filtering can only narrow that list, not extend it.
CustomHeroesPlugin.custom_heroes = {
    "npc_dota_hero_flasaro",
    "npc_dota_hero_onelosthero",
    "npc_dota_hero_moosestache",
    "npc_dota_hero_occupational_hazard",
}

function CustomHeroesPlugin:Init()
    --print("[CustomHeroesPlugin] found")
end

local function is_custom(name)
    if name == nil then return false end
    for _,n in ipairs(CustomHeroesPlugin.custom_heroes) do
        if n == name then return true end
    end
    return false
end

-- Hide custom heroes from the pick grid. herolist.txt is the master selectable
-- set; availability filtering is a SUBSET of it, so we switch the picker to an
-- explicit set of every NON-custom hero, leaving the custom heroes unavailable.
local function hide_custom_heroes()
    local herolist = LoadKeyValues('scripts/npc/herolist.txt')
    if herolist == nil or not next(herolist) then return end

    GameRules:SetHideBlacklistedHeroes(true)
    GameRules:GetGameModeEntity():SetPlayerHeroAvailabilityFiltered(true)
    for iPlayer = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayer(iPlayer) then
            for name,_ in pairs(herolist) do
                if not is_custom(name) then
                    local id = DOTAGameManager:GetHeroIDByName(name)
                    if id ~= nil and id > 0 then
                        GameRules:AddHeroToPlayerAvailability(iPlayer, id)
                    end
                end
            end
        end
    end
end

-- Force-create any custom hero whose player ended up WITHOUT an assigned hero.
-- A server-only custom hero (defined in npc_heroes_custom.txt with a recycled
-- HeroID) is selectable but the engine's default pick->spawn handshake does not
-- always create the hero entity for the player (the client has no such hero).
-- CreateHeroForPlayer is pure server-side and bypasses that, so the hero loads.
local function ensure_custom_heroes_spawned()
    for iPlayer = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayer(iPlayer) then
            local name = PlayerResource:GetSelectedHeroName(iPlayer)
            if is_custom(name) then
                local hPlayer = PlayerResource:GetPlayer(iPlayer)
                if hPlayer ~= nil and hPlayer:GetAssignedHero() == nil then
                    CreateHeroForPlayer(name, hPlayer)
                end
            end
        end
    end
end

-- This file is require()'d for every plugin regardless of its enabled state, so
-- this listener is ALWAYS registered (the plugin system would not call a disabled
-- plugin's ApplySettings). Note: GetAllSetting returns booleans as true/false.
ListenToGameEvent("game_rules_state_change", function()
    local state = GameRules:State_Get()

    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
        local settings = PluginSystem:GetAllSetting("custom_heroes")
        -- toggle ON (checked) -> custom heroes allowed; herolist already shows them.
        -- toggle OFF (default) -> hide them from the grid.
        if not (settings ~= nil and settings.enabled == true) then
            hide_custom_heroes()
        end
    elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        -- Give the engine a moment to do its own spawn, then backfill any custom
        -- hero that failed to spawn.
        Timers:CreateTimer(1.0, ensure_custom_heroes_spawned)
    end
end, nil)
