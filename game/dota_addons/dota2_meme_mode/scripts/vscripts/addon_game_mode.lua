-- Generated from template
function _G.softRequire(file)
	_G.dummyEnt = dummyEnt or Entities:CreateByClassname("info_target")
	local happy,msg = pcall(require,file)
	if not happy then
		dummyEnt:SetThink(function()
			error(msg,2)
		end)
	end
end

if CMemeModeGameMode == nil then
	CMemeModeGameMode = class({})
end

require("utils/timers")
require("utils/toolbox")
require("plugin_system/main")

function Precache( context )
	
	local file = LoadKeyValues('scripts/vscripts/plugin_system/precache_list.txt')
    if not (file == nil or not next(file)) then
        for k,v in pairs(file) do
			PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_" .. k .. ".vsndevts", context)
		end
    end
	PrecacheResource("soundfile", "soundevents/custom_sounds.vsndevts", context)
	PrecacheResource( "particle", "particles/tickets_gain.vpcf", context )
	PrecacheResource( "particle", "particles/souls/ward_skull_rubick.vpcf", context )

	-- Precache custom heroes (Flasaro, etc.). Vanilla heroes are auto-precached
	-- when selected, but custom heroes defined in npc_heroes_custom.txt are NOT,
	-- so without this the hero spawns server-side (model appears) while the CLIENT
	-- fails to fully instantiate it -- no ability bar, no portrait, no control.
	local custom_heroes = LoadKeyValues('scripts/npc/npc_heroes_custom.txt')
	if custom_heroes ~= nil then
		for hero_name, hero_data in pairs(custom_heroes) do
			if type(hero_data) == "table" then
				PrecacheUnitByNameSync(hero_name, context)
			end
		end
	end

	-- Mr.Bomber's ult is techies_land_mines (Proximity Mines) and his Ability5 is
	-- techies_minefield_sign, but his BaseClass is Gyrocopter, so the Land Mine model
	-- (models/heroes/techies/fx_techiesfx_mine.vmdl) and the mine particles/FX are never
	-- auto-precached -> "RESOURCE_TYPE_MODEL ... not loaded" when a mine spawns. Precache the
	-- Techies hero (pulls all its ability resources) + the mine model explicitly to be safe.
	PrecacheResource("model", "models/heroes/techies/fx_techiesfx_mine.vmdl", context)
	PrecacheUnitByNameSync("npc_dota_hero_techies", context)
end
function Activate()
	GameRules.AddonTemplate = CMemeModeGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CMemeModeGameMode:InitGameMode()
	local gm = GameRules:GetGameModeEntity()
	gm:SetThink( "OnThink", self, "GlobalThink", 2 )
	gm:SetWeatherEffectsDisabled(false)
	PluginSystem:Init()
	softRequire("meme_diag")   -- registers 'meme_diag_start'/'meme_diag_stop' console cmds; dormant until used
end

function CMemeModeGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end