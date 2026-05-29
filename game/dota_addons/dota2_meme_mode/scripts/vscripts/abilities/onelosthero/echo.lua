--[[
	OneLostHero — shared Echo system.

	An Echo is a short-lived clone-like afterimage (npc_onelosthero_echo, Riki model).
	Design pillars: Echoes are fragile, temporary, never farm, never become an illusion army.
	Each ability creates and tracks its own Echoes; this module is the shared toolbox.

	Loaded via require("abilities/onelosthero/echo"); also registers modifier_onelosthero_echo.
	All gameplay numbers come from KV via the calling ability; this module takes already-
	resolved values through `opts`.
]]

LinkLuaModifier("modifier_onelosthero_echo", "abilities/onelosthero/echo", LUA_MODIFIER_MOTION_NONE)

local Echo = {}

local ECHO_TINT = { 120, 90, 255 } -- blue-violet "Echo energy" placeholder tint
local ECHO_PARTICLE = "particles/units/heroes/hero_spectre/spectre_desolate.vpcf"

------------------------------------------------------------------------------------
-- Creation
------------------------------------------------------------------------------------
-- opts = {
--   duration             seconds the Echo lives (required)
--   killable             false = invulnerable+untargetable visual afterimage,
--                        true  = a real unit enemies can hit (False Hero)
--   incoming_damage_pct  only meaningful when killable (e.g. 250 = +150% dmg)
--   canSwap              may the hero swap with this Echo
--   can_attack           Echo auto-attacks (False Hero); otherwise it's disarmed
--   attack_damage        flat attack damage to set when can_attack
--   controllable         give the owning player control (default false)
--   movespeed            optional movespeed override
--   source               string ability name (tracking/debug)
--   onExpire(unit)       natural-expiry callback
--   onDeath(unit)        early-death (killed) callback
--   onHeroAttacked(unit) called when an enemy hero's attack lands on the Echo
-- }
function Echo:Create(owner, ability, vOrigin, opts)
	if not IsServer() then return nil end
	opts = opts or {}
	local team = owner:GetTeamNumber()
	local unit

	if opts.illusion then
		-- A real illusion copy of the hero (Phantom-Lancer style): identical model, name,
		-- healthbar and items, and it adopts the custom model automatically once one exists.
		-- The engine's illusion modifier governs damage dealt/taken; our tracking modifier
		-- (added below) only handles swap eligibility, the hero-attack detonation hook, and
		-- the 10s lifetime. The "+1" duration is a safety net behind our modifier's expiry.
		local list = CreateIllusions(owner, owner, {
			outgoing_damage = opts.outgoing_damage or 100,
			incoming_damage = opts.incoming_damage or 100,
			bounty_base = 0,
			bounty_growth = 0,
			duration = (opts.duration or 2.0) + 1.0,
		}, 1, owner:GetHullRadius(), false, true)
		unit = list and list[1]
		if not unit then return nil end
		unit:SetAbsOrigin(vOrigin)
		FindClearSpaceForUnit(unit, vOrigin, true)
	else
		unit = CreateUnitByName("npc_onelosthero_echo", vOrigin, true, owner, owner, team)
		if not unit then return nil end
		unit:SetOwner(owner)
		if opts.controllable then
			local pid = owner:GetPlayerOwnerID()
			if pid ~= nil and pid >= 0 then unit:SetControllableByPlayer(pid, true) end
		end
		unit:SetRenderColor(ECHO_TINT[1], ECHO_TINT[2], ECHO_TINT[3])
		if opts.movespeed then unit:SetBaseMoveSpeed(opts.movespeed) end
		if opts.can_attack and opts.attack_damage then
			unit:SetBaseDamageMin(opts.attack_damage)
			unit:SetBaseDamageMax(opts.attack_damage)
		end
	end

	unit:SetForwardVector(owner:GetForwardVector())
	local now = GameRules:GetGameTime()
	unit.olh_echo = {
		owner            = owner,
		ability          = ability,
		canSwap          = opts.canSwap and true or false,
		source           = opts.source,
		killable         = opts.killable and true or false,
		createdAt        = now,
		expiresAt        = now + (opts.duration or 2.0),
		onExpire         = opts.onExpire,
		onDeath          = opts.onDeath,
		onHeroAttacked   = opts.onHeroAttacked,
		heroAttackFired  = false,
		expired          = false,
		moveDest         = opts.move_dest,
	}

	unit:AddNewModifier(owner, ability, "modifier_onelosthero_echo", {
		duration      = opts.duration or 2.0,
		killable      = opts.killable and 1 or 0,
		dmg_pct       = opts.incoming_damage_pct or 100,
		can_attack    = opts.can_attack and 1 or 0,
		is_illusion   = opts.illusion and 1 or 0,
		drive_forward = opts.drive_forward and 1 or 0,
	})

	owner.olh_active_echoes = owner.olh_active_echoes or {}
	owner.olh_active_echoes[unit:entindex()] = unit

	if not opts.illusion then -- keep illusions visually identical to the real hero
		unit.olh_echo.ambientFx = ParticleManager:CreateParticle(ECHO_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, unit)
	end
	return unit
end

-- Stop + free a stored ambient particle so it never lingers after the Echo is gone.
local function destroyAmbient(unit)
	local data = unit and unit.olh_echo
	if data and data.ambientFx then
		ParticleManager:DestroyParticle(data.ambientFx, false)
		ParticleManager:ReleaseParticleIndex(data.ambientFx)
		data.ambientFx = nil
	end
end

function Echo:GetActiveEchoes(owner)
	local out = {}
	if owner and owner.olh_active_echoes then
		for idx, unit in pairs(owner.olh_active_echoes) do
			if self:IsValid(unit) then out[#out + 1] = unit
			else owner.olh_active_echoes[idx] = nil end
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

-- Single teardown path. `killed` = destroyed early by damage (vs. natural expiry / forced).
function Echo:_Teardown(unit, killed)
	if not IsServer() or unit == nil or unit:IsNull() then return end
	local data = unit.olh_echo
	if data then
		if data.expired then return end
		data.expired = true
		if data.owner and not data.owner:IsNull() and data.owner.olh_active_echoes then
			data.owner.olh_active_echoes[unit:entindex()] = nil
		end
		if killed and data.onDeath then data.onDeath(unit)
		elseif (not killed) and data.onExpire then data.onExpire(unit) end
	end
	destroyAmbient(unit)
	ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image.vpcf", PATTACH_ABSORIGIN, unit)
	if unit:IsAlive() then unit:ForceKill(false) end
	unit:RemoveSelf()
end

-- Forced removal WITHOUT firing onExpire/onDeath (used for safe destruction on swap).
function Echo:RemoveSafely(unit)
	if not IsServer() or unit == nil or unit:IsNull() then return end
	if unit.olh_echo then
		unit.olh_echo.expired = true
		local owner = unit.olh_echo.owner
		if owner and not owner:IsNull() and owner.olh_active_echoes then
			owner.olh_active_echoes[unit:entindex()] = nil
		end
	end
	destroyAmbient(unit)
	ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/void_spirit_astral_step.vpcf", PATTACH_ABSORIGIN, unit)
	if unit:IsAlive() then unit:ForceKill(false) end
	unit:RemoveSelf()
end

function Echo:Expire(unit)
	self:_Teardown(unit, false)
end

------------------------------------------------------------------------------------
-- Swap
------------------------------------------------------------------------------------
function Echo:CanSwap(caster, echo)
	if caster == nil or caster:IsNull() or not caster:IsAlive() then return false end
	if not self:IsValid(echo) then return false end
	if not echo.olh_echo.canSwap then return false end
	if caster:IsStunned() or caster:IsHexed() or caster:IsRooted()
		or caster:IsCommandRestricted() or caster:IsNightmared() then return false end
	return true
end

-- Moves the caster to the echo's location (and the echo to the caster's). Returns the
-- caster's PRE-swap origin on success (useful for Shard's fading-echo placement), else nil.
function Echo:Swap(caster, echo)
	if not IsServer() then return nil end
	if not self:CanSwap(caster, echo) then return nil end

	local casterPos = caster:GetAbsOrigin()
	local echoPos   = echo:GetAbsOrigin()
	local casterFwd = caster:GetForwardVector()
	local echoFwd   = echo:GetForwardVector()

	caster:SetAbsOrigin(echoPos)
	FindClearSpaceForUnit(caster, echoPos, true)
	caster:SetForwardVector(echoFwd)

	echo:SetAbsOrigin(casterPos)
	FindClearSpaceForUnit(echo, casterPos, true)
	echo:SetForwardVector(casterFwd)

	ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/void_spirit_astral_step.vpcf", PATTACH_ABSORIGIN, caster)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
	return casterPos
end

------------------------------------------------------------------------------------
-- Geometry helpers
------------------------------------------------------------------------------------
function Echo:FindEnemiesInLine(caster, startPos, endPos, width)
	return FindUnitsInLine(caster:GetTeamNumber(), startPos, endPos, nil, width,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE)
end

function Echo:FindEnemiesInRadius(caster, pos, radius)
	return FindUnitsInRadius(caster:GetTeamNumber(), pos, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
end

function Echo:IsBehindOrSide(attacker, target, angleDeg)
	local toAttacker = (attacker:GetAbsOrigin() - target:GetAbsOrigin()):Normalized()
	local back = target:GetForwardVector() * -1
	local dot = back.x * toAttacker.x + back.y * toAttacker.y
	dot = math.max(-1, math.min(1, dot))
	return math.deg(math.acos(dot)) <= (angleDeg / 2)
end

-- Shard / Scepter checks that survive the API method being unavailable post-patch
-- (caster:HasShard() came back nil and crashed). Fall back to the item modifiers.
function Echo:HasShard(unit)
	if unit.HasShard then return unit:HasShard() end
	return unit:HasModifier("modifier_item_aghanims_shard")
end
function Echo:HasScepter(unit)
	if unit.HasScepter then return unit:HasScepter() end
	return unit:HasModifier("modifier_item_ultimate_scepter")
end

-- Play the first activity (by global enum name) that actually exists on this build, as a
-- gesture. Lets us use Kez's specific ability activities with safe fallbacks: an unknown
-- enum name is just skipped (no error, no T-pose).
function Echo:PlayGesture(unit, names)
	for _, n in ipairs(names) do
		local act = _G[n]
		if act ~= nil then
			unit:StartGesture(act)
			return n
		end
	end
	return nil
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
	self.canAttack = (params and params.can_attack == 1) or false
	self.isIllusion = (params and params.is_illusion == 1) or false
	if IsServer() and params and params.drive_forward == 1 then
		self:StartIntervalThink(0.5)
	end
end

-- Keep an autonomous Echo (False Hero) advancing toward its waypoint. Re-issues the
-- attack-move only when it isn't already attacking something, so it still fights along the way
-- but never just stalls after the initial order is dropped.
function modifier_onelosthero_echo:OnIntervalThink()
	if not IsServer() then return end
	local unit = self:GetParent()
	if not unit or unit:IsNull() or not unit:IsAlive() then return end
	local data = unit.olh_echo
	if not data or not data.moveDest then return end
	if unit:GetAggroTarget() ~= nil then return end -- currently attacking; leave it
	if (unit:GetAbsOrigin() - data.moveDest):Length2D() < 150 then return end -- arrived
	ExecuteOrderFromTable({
		UnitIndex = unit:entindex(),
		OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
		Position = data.moveDest,
		Queue = false,
	})
end

function modifier_onelosthero_echo:CheckState()
	-- Real illusions keep their native behavior (collide, attack, show on minimap, be
	-- killable) so they read as the real hero; we only ride along for tracking/detonation.
	if self.isIllusion then return {} end
	local state = {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP]    = true,
	}
	state[MODIFIER_STATE_DISARMED] = not self.canAttack
	if not self.killable then
		state[MODIFIER_STATE_INVULNERABLE]  = true
		state[MODIFIER_STATE_UNTARGETABLE]  = true
		state[MODIFIER_STATE_NO_HEALTH_BAR] = true
	end
	return state
end

function modifier_onelosthero_echo:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_onelosthero_echo:GetModifierIncomingDamage_Percentage()
	if self.isIllusion then return 0 end -- the engine's illusion modifier governs this
	if self.killable then return self.dmgPct - 100 end
	return 0
end

-- Detonate-on-enemy-hero-attack (False Hero). Lane creeps/neutrals/towers do not qualify.
function modifier_onelosthero_echo:OnAttackLanded(event)
	if not IsServer() then return end
	local unit = self:GetParent()
	if event.target ~= unit then return end
	local data = unit.olh_echo
	if not data or data.heroAttackFired or not data.onHeroAttacked then return end
	local attacker = event.attacker
	if not attacker or attacker:IsNull() then return end
	if attacker:GetTeamNumber() == unit:GetTeamNumber() then return end
	if not attacker:IsRealHero() then return end -- creeps/towers/neutrals don't trigger
	data.heroAttackFired = true
	data.onHeroAttacked(unit)
end

function modifier_onelosthero_echo:OnDestroy()
	if not IsServer() then return end
	local unit = self:GetParent()
	if not unit or unit:IsNull() then return end
	if unit.olh_echo and not unit.olh_echo.expired then
		Echo:_Teardown(unit, not unit:IsAlive())
	end
end

return Echo
