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
    "npc_dota_hero_mr_badhabits",
    "npc_dota_hero_mr_bomber",
}

-- Maps each custom hero to its per-hero "include" setting key (see settings.txt).
-- When the master "all_heroes" toggle is off, only heroes whose key is on appear.
CustomHeroesPlugin.setting_key = {
    npc_dota_hero_flasaro            = "hero_flasaro",
    npc_dota_hero_onelosthero        = "hero_onelosthero",
    npc_dota_hero_moosestache        = "hero_moosestache",
    npc_dota_hero_occupational_hazard = "hero_occupational_hazard",
    npc_dota_hero_mr_badhabits       = "hero_mr_badhabits",
    npc_dota_hero_mr_bomber          = "hero_mr_bomber",
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

-- Read a boolean plugin setting, defaulting when missing. GetAllSetting returns
-- booleans as true/false.
local function setting_on(settings, key, default_on)
    if settings == nil then return default_on end
    local v = settings[key]
    if v == nil then return default_on end
    return v == true
end

-- Build the pick-grid availability. herolist.txt is the master selectable set;
-- availability filtering can only NARROW it. Cases:
--   plugin off            -> hide every custom hero (allow only non-customs).
--   on + "All" toggle on  -> leave the grid untouched (all heroes show).
--   on + "All" toggle off -> allow non-customs + each custom whose toggle is on.
local function apply_hero_availability()
    local herolist = LoadKeyValues('scripts/npc/herolist.txt')
    if herolist == nil or not next(herolist) then return end

    local settings = PluginSystem:GetAllSetting("custom_heroes")
    local enabled = (settings ~= nil and settings.enabled == true)
    local all_on = setting_on(settings, "all_heroes", true)

    -- Enabled + master "All": leave the pick grid untouched so every herolist hero
    -- (including all customs) shows. This is the original, proven behaviour and
    -- avoids round-tripping the custom heroes' recycled HeroIDs through the
    -- availability filter. We only NARROW the grid in the other cases below.
    if enabled and all_on then
        return
    end

    local function custom_allowed(name)
        if not enabled then return false end          -- plugin off -> no custom heroes
        local key = CustomHeroesPlugin.setting_key[name]
        if key == nil then return true end            -- unmapped custom -> allow by default
        return setting_on(settings, key, true)        -- per-hero toggle (default on)
    end

    GameRules:SetHideBlacklistedHeroes(true)
    GameRules:GetGameModeEntity():SetPlayerHeroAvailabilityFiltered(true)
    for iPlayer = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayer(iPlayer) then
            for name,_ in pairs(herolist) do
                local allow = true
                if is_custom(name) then allow = custom_allowed(name) end
                if allow then
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
        -- Always apply availability: off -> no customs; on -> all (or just the
        -- selected ones when the master "All" toggle is off).
        apply_hero_availability()
    elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        -- Give the engine a moment to do its own spawn, then backfill any custom
        -- hero that failed to spawn.
        Timers:CreateTimer(1.0, ensure_custom_heroes_spawned)
    end
end, nil)
