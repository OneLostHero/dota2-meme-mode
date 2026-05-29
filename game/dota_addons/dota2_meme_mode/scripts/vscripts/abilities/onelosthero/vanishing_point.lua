--[[
	OneLostHero — R: Vanishing Point
	Vanish (invisible) and charge a finishing strike while gaining move speed and being unable
	to attack. On release (auto after charge_duration, or recast to release early) the hero
	reappears in a circular burst that damages and fears enemies; active Echoes release weaker
	bursts. Charge time scales the damage. All values from KV.

	Shard (Unseen Exchange): one free Echo swap during the ult; the abandoned Echo detonates on
	release and the warning is briefly suppressed.
	Scepter (Many Lost, One Returned): spawns extra invisible Echoes that spread outward and add
	weaker fear bursts on release.
]]
local Echo = require("abilities/onelosthero/echo")

LinkLuaModifier("modifier_onelosthero_vanishing_point_charge", "abilities/onelosthero/vanishing_point", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_onelosthero_vanishing_point_fear", "abilities/onelosthero/vanishing_point", LUA_MODIFIER_MOTION_NONE)

onelosthero_vanishing_point = class({})

function onelosthero_vanishing_point:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_4
end

function onelosthero_vanishing_point:OnSpellStart()
	local caster = self:GetCaster()

	-- recast while charging => release early
	if self._charging then
		self:Release()
		return
	end

	local chargeDuration = self:GetSpecialValueFor("charge_duration")

	self._charging = true
	self._chargeStart = GameRules:GetGameTime()
	self._chargeDuration = chargeDuration
	self._scepterEchoes = {}

	-- Force the Raptor Dance gesture (ACT_DOTA_CAST_ABILITY_4 = the hero's ult cast animation
	-- on the Kez model) so the flourish plays even though the charge applies right away.
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_4)
	caster:AddNewModifier(caster, self, "modifier_onelosthero_vanishing_point_charge", { duration = chargeDuration })
	caster:EmitSound("Hero_Nightstalker.Darkness")

	-- Scepter: extra invisible Echoes spread outward during the charge
	if caster:HasScepter() then
		local count   = self:GetSpecialValueFor("scepter_extra_echoes")
		local spread  = self:GetSpecialValueFor("scepter_echo_spread_distance")
		for i = 1, count do
			local angle = (i / count) * 2 * math.pi
			local offset = Vector(math.cos(angle), math.sin(angle), 0) * spread
			local pos = caster:GetAbsOrigin() + offset
			local echo = Echo:Create(caster, self, pos, {
				duration = chargeDuration + 0.5, killable = false, canSwap = false, source = "vanishing_point_scepter",
			})
			if echo then table.insert(self._scepterEchoes, echo) end
		end
	end

	-- allow recast-to-release; auto-release at the end of the charge
	self:EndCooldown()
	Timers:CreateTimer(chargeDuration, function()
		if self._charging then self:Release() end
	end)
end

function onelosthero_vanishing_point:Release()
	if not IsServer() or not self._charging then return end
	self._charging = false
	local caster = self:GetCaster()

	caster:RemoveModifierByName("modifier_onelosthero_vanishing_point_charge")

	local elapsed = GameRules:GetGameTime() - (self._chargeStart or GameRules:GetGameTime())
	local frac = math.max(0, math.min(1, elapsed / (self._chargeDuration or 1)))
	local baseDamage    = self:GetSpecialValueFor("base_damage")
	local maxChargeBonus = self:GetSpecialValueFor("max_charge_bonus_pct")
	local finalDamage = baseDamage * (1 + frac * maxChargeBonus / 100)

	local radius      = self:GetSpecialValueFor("release_radius")
	local fearDuration = self:GetSpecialValueFor("fear_duration")
	local echoBurstPct = self:GetSpecialValueFor("echo_burst_damage_pct")
	local pos = caster:GetAbsOrigin()

	-- main burst VFX/SFX
	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_night_stalker/nightstalker_void.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, pos)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, radius, radius))
	Timers:CreateTimer(2.0, function()
		ParticleManager:DestroyParticle(pfx, false)
		ParticleManager:ReleaseParticleIndex(pfx)
	end)
	caster:EmitSound("Hero_Nightstalker.Void")

	self:BurstAt(caster, pos, finalDamage, fearDuration, radius, 100)

	-- active Echoes release weaker bursts
	for _, echo in pairs(Echo:GetActiveEchoes(caster)) do
		self:BurstAt(caster, echo:GetAbsOrigin(), finalDamage * (echoBurstPct / 100), fearDuration, radius, echoBurstPct)
	end

	-- Scepter Echo bursts (weaker damage + scaled fear)
	if caster:HasScepter() then
		local scepterBurstPct = self:GetSpecialValueFor("scepter_echo_burst_damage_pct")
		local scepterFearPct  = self:GetSpecialValueFor("scepter_echo_fear_pct")
		for _, echo in pairs(self._scepterEchoes) do
			if Echo:IsValid(echo) then
				self:BurstAt(caster, echo:GetAbsOrigin(), finalDamage * (scepterBurstPct / 100), fearDuration * (scepterFearPct / 100), radius, scepterBurstPct)
			end
		end
	end

	-- (Shard no longer affects Vanishing Point — it now upgrades False Hero.)

	-- cleanup: expire all remaining Echoes spawned for the ult
	for _, echo in pairs(self._scepterEchoes) do
		if echo and not echo:IsNull() then Echo:Expire(echo) end
	end
	self._scepterEchoes = {}

	self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
end

-- Does the lvl25-left talent (fear pierces debuff immunity) apply?
function onelosthero_vanishing_point:FearPiercesImmunity()
	local t = self:GetCaster():FindAbilityByName("special_bonus_unique_onelosthero_fear_pierce")
	return t ~= nil and t:GetLevel() > 0
end

-- Damage + fear all enemies around a point. Fear respects debuff immunity unless the
-- lvl25 talent is taken (then it pierces). Scepter Echo bursts inherit this via the same path.
function onelosthero_vanishing_point:BurstAt(caster, pos, damage, fearDuration, radius, _pct)
	local pierce = self:FearPiercesImmunity()
	for _, enemy in pairs(Echo:FindEnemiesInRadius(caster, pos, radius)) do
		if enemy and not enemy:IsNull() then
			ApplyDamage({
				victim = enemy, attacker = caster, damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL, ability = self,
			})
			if pierce or not enemy:IsMagicImmune() then
				enemy:AddNewModifier(caster, self, "modifier_onelosthero_vanishing_point_fear", {
					duration = fearDuration, src_x = pos.x, src_y = pos.y, src_z = pos.z,
					pierce = pierce and 1 or 0,
				})
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Charge: invisible, faster, cannot attack.
--------------------------------------------------------------------------------
modifier_onelosthero_vanishing_point_charge = class({})
function modifier_onelosthero_vanishing_point_charge:IsPurgable() return false end
function modifier_onelosthero_vanishing_point_charge:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_onelosthero_vanishing_point_charge:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_onelosthero_vanishing_point_charge:GetModifierMoveSpeedBonus_Percentage()
	return self:GetAbility():GetSpecialValueFor("movespeed_bonus_pct")
end
function modifier_onelosthero_vanishing_point_charge:CheckState()
	return {
		[MODIFIER_STATE_INVISIBLE] = true,
		[MODIFIER_STATE_DISARMED]  = true,
	}
end
function modifier_onelosthero_vanishing_point_charge:GetEffectName()
	return "particles/units/heroes/hero_spectre/spectre_desolate.vpcf"
end
function modifier_onelosthero_vanishing_point_charge:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
-- Fear: command-restricted; periodically forced to run away from the burst source.
--------------------------------------------------------------------------------
modifier_onelosthero_vanishing_point_fear = class({})
function modifier_onelosthero_vanishing_point_fear:IsDebuff() return true end
-- Non-purgable when it pierces (lvl25 talent): a non-purgable Lua modifier persists through
-- BKB's debuff immunity, so the fear sticks. Otherwise it's a normal purgable debuff.
function modifier_onelosthero_vanishing_point_fear:IsPurgable() return not self.pierce end
function modifier_onelosthero_vanishing_point_fear:OnCreated(params)
	self.pierce = params and params.pierce == 1
	if params and params.src_x then
		self.sourcePos = Vector(params.src_x, params.src_y, params.src_z)
	else
		self.sourcePos = self:GetCaster():GetAbsOrigin()
	end
	if IsServer() then
		self:StartIntervalThink(0.1)
		self:OnIntervalThink()
	end
end
function modifier_onelosthero_vanishing_point_fear:OnIntervalThink()
	if not IsServer() then return end
	local parent = self:GetParent()
	if not parent or parent:IsNull() or not parent:IsAlive() then return end
	local away = (parent:GetAbsOrigin() - self.sourcePos)
	away.z = 0
	if away:Length2D() < 1 then away = parent:GetForwardVector() end
	away = away:Normalized()
	local dest = parent:GetAbsOrigin() + away * 300
	ExecuteOrderFromTable({
		UnitIndex = parent:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = dest,
		Queue = false,
	})
end
-- Command-restricted only: the engine's FEARED state would override our scripted move-away
-- orders, so we drive the flee ourselves (works on command-restricted units, which only blocks
-- PLAYER input). The visible effect is the enemy running away from the burst.
function modifier_onelosthero_vanishing_point_fear:CheckState()
	return { [MODIFIER_STATE_COMMAND_RESTRICTED] = true }
end
function modifier_onelosthero_vanishing_point_fear:GetEffectName()
	return "particles/units/heroes/hero_spectre/spectre_desolate.vpcf"
end
function modifier_onelosthero_vanishing_point_fear:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
