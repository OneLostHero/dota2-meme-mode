--[[
	OneLostHero — shared Echo system.

	An Echo is a short-lived clone-like afterimage (npc_onelosthero_echo, Riki model).
	Design pillars (from the brief): Echoes are fragile, temporary, never farm, never
	become an illusion army. Each ability creates and tracks its own Echoes; this module
	is the shared toolbox for creating / expiring / swapping with them and a couple of
	geometry helpers.

	Loaded via require("abilities/onelosthero/echo") at the top of each ability file,
	which also registers modifier_onelosthero_echo.

	NOTE: All gameplay numbers come from KV via the calling ability's GetSpecialValueFor;
	this module only takes already-resolved values through `opts`.
]]

LinkLuaModifier("modifier_onelosthero_echo", "abilities/onelosthero/echo", LUA_MODIFIER_MOTION_NONE)

local Echo = {}

local ECHO_TINT = { 120, 90, 255 } -- blue-violet "Echo energy" placeholder tint
local ECHO_PARTICLE = "particles/units/heroes/hero_spectre/spectre_desolate.vpcf"

------------------------------------------------------------------------------------
-- Creation
------------------------------------------------------------------------------------
-- owner   : the hero
-- ability : the source ability (for damage attribution / GetSpecialValueFor)
-- vOrigin : spawn position
-- opts = {
--   duration            = seconds the Echo lives (required, from KV echo/clone_duration)
--   killable            = bool; false = invulnerable+untargetable visual afterimage,
--                                true  = a real fragile clone enemies can destroy (False Hero)
--   incoming_damage_pct  = number; only meaningful when killable (e.g. 250 = takes +150% dmg)
--   canSwap             = bool; may the hero swap with this Echo
--   movespeed           = optional movespeed override
--   source              = string ability name (tracking/debug)
--   onExpire(unit)      = optional callback when the Echo expires naturally
--   onDeath(unit)       = optional callback when a killable Echo is destroyed early
-- }
function Echo:Create(owner, ability, vOrigin, opts)
	if not IsServer() then return nil end
	opts = opts or {}
	local team = owner:GetTeamNumber()
	local unit = CreateUnitByName("npc_onelosthero_echo", vOrigin, true, owner, owner, team)
	if not unit then return nil end

	unit:SetOwner(owner)
	local pid = owner:GetPlayerOwnerID()
	if pid ~= nil and pid >= 0 then
		unit:SetControllableByPlayer(pid, true)
	end
	unit:SetForwardVector(owner:GetForwardVector())
	unit:SetRenderColor(ECHO_TINT[1], ECHO_TINT[2], ECHO_TINT[3])
	if opts.movespeed then
		unit:SetBaseMoveSpeed(opts.movespeed)
	end

	-- runtime book-keeping table on the unit
	local now = GameRules:GetGameTime()
	unit.olh_echo = {
		owner            = owner,
		ability          = ability,
		canSwap          = opts.canSwap and true or false,
		source           = opts.source,
		killable         = opts.killable and true or false,
		incomingDamagePct = opts.incoming_damage_pct,
		createdAt        = now,
		expiresAt        = now + (opts.duration or 2.0),
		onExpire         = opts.onExpire,
		onDeath          = opts.onDeath,
		expired          = false,
	}

	unit:AddNewModifier(owner, ability, "modifier_onelosthero_echo", {
		duration  = opts.duration or 2.0,
		killable  = opts.killable and 1 or 0,
		dmg_pct   = opts.incoming_damage_pct or 100,
	})

	-- register on the owner so the ultimate can enumerate active Echoes
	owner.olh_active_echoes = owner.olh_active_echoes or {}
	owner.olh_active_echoes[unit:entindex()] = unit

	ParticleManager:CreateParticle(ECHO_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, unit)
	return unit
end

-- Returns a clean list of the owner's currently-valid Echoes.
function Echo:GetActiveEchoes(owner)
	local out = {}
	if owner and owner.olh_active_echoes then
		for idx, unit in pairs(owner.olh_active_echoes) do
			if self:IsValid(unit) then
				out[#out + 1] = unit
			else
				owner.olh_active_echoes[idx] = nil
			end
		end
	end
	return out
end

------------------------------------------------------------------------------------
-- Expiry / cleanup
------------------------------------------------------------------------------------
function Echo:IsValid(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive()
		and unit.olh_echo ~= nil and not unit.olh_echo.expired
end

-- Single teardown path. `killed` = the Echo was destroyed early by damage (vs. natural
-- expiry / forced removal). Fires the matching callback exactly once and removes the unit.
function Echo:_Teardown(unit, killed)
	if not IsServer() or unit == nil or unit:IsNull() then return end
	local data = unit.olh_echo
	if data then
		if data.expired then return end
		data.expired = true
		if data.owner and not data.owner:IsNull() and data.owner.olh_active_echoes then
			data.owner.olh_active_echoes[unit:entindex()] = nil
		end
		if killed and data.onDeath then
			data.onDeath(unit)
		elseif (not killed) and data.onExpire then
			data.onExpire(unit)
		end
	end
	ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image.vpcf", PATTACH_ABSORIGIN, unit)
	if unit:IsAlive() then
		unit:ForceKill(false)
	end
	unit:RemoveSelf()
end

-- Forced expiry (e.g. consumed after a swap, or window ended).
function Echo:Expire(unit)
	self:_Teardown(unit, false)
end

------------------------------------------------------------------------------------
-- Swap
------------------------------------------------------------------------------------
-- Returns true on success. Runs the brief's full validity checklist.
function Echo:CanSwap(caster, echo)
	if caster == nil or caster:IsNull() or not caster:IsAlive() then return false end
	if not self:IsValid(echo) then return false end
	if not echo.olh_echo.canSwap then return false end
	if caster:IsStunned() or caster:IsHexed() or caster:IsRooted()
		or caster:IsCommandRestricted() or caster:IsNightmared() then
		return false
	end
	return true
end

function Echo:Swap(caster, echo)
	if not IsServer() then return false end
	if not self:CanSwap(caster, echo) then return false end

	local casterPos = caster:GetAbsOrigin()
	local echoPos   = echo:GetAbsOrigin()
	local casterFwd = caster:GetForwardVector()
	local echoFwd   = echo:GetForwardVector()

	caster:SetAbsOrigin(echoPos)
	FindClearSpaceForUnit(caster, echoPos, true)
	caster:SetForwardVector(echoFwd) -- preserve facing intent

	echo:SetAbsOrigin(casterPos)
	FindClearSpaceForUnit(echo, casterPos, true)
	echo:SetForwardVector(casterFwd)

	-- placeholder swap VFX/SFX
	ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/void_spirit_astral_step.vpcf", PATTACH_ABSORIGIN, caster)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
	return true
end

------------------------------------------------------------------------------------
-- Geometry helpers
------------------------------------------------------------------------------------
function Echo:FindEnemiesInLine(caster, startPos, endPos, width)
	return FindUnitsInLine(
		caster:GetTeamNumber(), startPos, endPos, nil, width,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE
	)
end

function Echo:FindEnemiesInRadius(caster, pos, radius)
	return FindUnitsInRadius(
		caster:GetTeamNumber(), pos, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
	)
end

-- Is `attacker` positioned to the side or behind `target`, within `angleDeg` of the
-- target's BACK (used by Blindspot Dagger). angleDeg is the full backstab arc.
function Echo:IsBehindOrSide(attacker, target, angleDeg)
	local toAttacker = (attacker:GetAbsOrigin() - target:GetAbsOrigin()):Normalized()
	local back = target:GetForwardVector() * -1
	local dot = back.x * toAttacker.x + back.y * toAttacker.y
	dot = math.max(-1, math.min(1, dot))
	local angle = math.deg(math.acos(dot))
	return angle <= (angleDeg / 2)
end

------------------------------------------------------------------------------------
-- modifier_onelosthero_echo — fragile / non-farming / afterimage state holder
------------------------------------------------------------------------------------
modifier_onelosthero_echo = class({})

function modifier_onelosthero_echo:IsHidden() return true end
function modifier_onelosthero_echo:IsPurgable() return false end
function modifier_onelosthero_echo:RemoveOnDeath() return true end

function modifier_onelosthero_echo:OnCreated(params)
	self.killable = (params and params.killable == 1) or false
	self.dmgPct = (params and params.dmg_pct) or 100
end

function modifier_onelosthero_echo:CheckState()
	local state = {
		[MODIFIER_STATE_DISARMED]            = true,  -- never attacks
		[MODIFIER_STATE_NO_UNIT_COLLISION]   = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP]      = true,
		[MODIFIER_STATE_UNSELECTABLE]        = false,
	}
	if not self.killable then
		state[MODIFIER_STATE_INVULNERABLE]   = true
		state[MODIFIER_STATE_UNTARGETABLE]   = true
		state[MODIFIER_STATE_NO_HEALTH_BAR]  = true
	end
	return state
end

function modifier_onelosthero_echo:DeclareFunctions()
	return { MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE }
end

-- Killable Echoes (clones) take scaled damage so they stay fragile per KV.
function modifier_onelosthero_echo:GetModifierIncomingDamage_Percentage()
	if self.killable then
		return self.dmgPct - 100
	end
	return 0
end

function modifier_onelosthero_echo:OnDestroy()
	if not IsServer() then return end
	local unit = self:GetParent()
	if not unit or unit:IsNull() then return end
	if unit.olh_echo and not unit.olh_echo.expired then
		-- RemoveOnDeath() means a killed Echo also lands here; distinguish by IsAlive().
		Echo:_Teardown(unit, not unit:IsAlive())
	end
end

return Echo
