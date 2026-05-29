--[[
	OneLostHero — E: False Hero
	Sends a fragile clone forward. Recast within swap_window to swap with it. If the clone
	is destroyed before it expires, it bursts: slowing and disarming nearby enemies.
	All values from KV.
]]
local Echo = require("abilities/onelosthero/echo")

LinkLuaModifier("modifier_onelosthero_false_hero_burst_slow", "abilities/onelosthero/false_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_onelosthero_false_hero_disarm", "abilities/onelosthero/false_hero", LUA_MODIFIER_MOTION_NONE)

onelosthero_false_hero = class({})

function onelosthero_false_hero:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_3
end

function onelosthero_false_hero:OnSpellStart()
	local caster = self:GetCaster()
	local now = GameRules:GetGameTime()

	-- ---- Swap branch ----
	if self._swapUntil and now <= self._swapUntil and Echo:IsValid(self._clone) then
		if Echo:Swap(caster, self._clone) then
			caster:GiveMana(self._lastManaCost or 0)
			self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
			-- clone keeps living after the swap until its own expiry/death
			self._swapUntil = nil
			return
		end
	end

	-- ---- Cast branch ----
	local startPos = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()
	local dir = (point - startPos)
	dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()

	local distance   = self:GetSpecialValueFor("clone_distance")
	local duration   = self:GetSpecialValueFor("clone_duration")
	local msPct      = self:GetSpecialValueFor("clone_movespeed_pct")
	local incomingPct = self:GetSpecialValueFor("clone_incoming_damage_pct")
	local swapWin    = self:GetSpecialValueFor("swap_window")
	self._lastManaCost = self:GetManaCost(self:GetLevel() - 1)

	local destination = startPos + dir * distance
	local moveSpeed = caster:GetIdealSpeedNoSlows() * (msPct / 100)

	ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image.vpcf", PATTACH_ABSORIGIN, caster)
	caster:EmitSound("Hero_Terrorblade.Reflection.Cast")

	local clone = Echo:Create(caster, self, startPos, {
		duration = duration,
		killable = true,
		incoming_damage_pct = incomingPct,
		canSwap = true,
		movespeed = moveSpeed,
		source = "false_hero",
		onDeath = function(unit) self:Burst(caster, unit:GetAbsOrigin()) end,
	})

	if clone then
		clone:SetForwardVector(dir)
		self._clone = clone
		self._swapUntil = now + swapWin
		-- send the clone forward
		ExecuteOrderFromTable({
			UnitIndex = clone:entindex(),
			OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
			Position = destination,
			Queue = false,
		})
	end
end

-- Burst: slow + disarm enemies around `pos`. Triggered only when the clone is killed early.
function onelosthero_false_hero:Burst(caster, pos)
	if not IsServer() then return end
	local radius        = self:GetSpecialValueFor("burst_radius")
	local slowDuration  = self:GetSpecialValueFor("burst_slow_duration")
	local disarmDuration = self:GetSpecialValueFor("disarm_duration")

	ParticleManager:CreateParticle("particles/units/heroes/hero_phantom_lancer/phantom_lancer_doppelganger_aoe.vpcf", PATTACH_WORLDORIGIN, nil)
	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_phantom_lancer/phantom_lancer_doppelganger_aoe.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, pos)
	ParticleManager:ReleaseParticleIndex(pfx)

	for _, enemy in pairs(Echo:FindEnemiesInRadius(caster, pos, radius)) do
		if enemy and not enemy:IsNull() then
			enemy:AddNewModifier(caster, self, "modifier_onelosthero_false_hero_burst_slow", { duration = slowDuration })
			enemy:AddNewModifier(caster, self, "modifier_onelosthero_false_hero_disarm", { duration = disarmDuration })
		end
	end
end

--------------------------------------------------------------------------------
-- Burst slow
--------------------------------------------------------------------------------
modifier_onelosthero_false_hero_burst_slow = class({})
function modifier_onelosthero_false_hero_burst_slow:IsDebuff() return true end
function modifier_onelosthero_false_hero_burst_slow:IsPurgable() return true end
function modifier_onelosthero_false_hero_burst_slow:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_onelosthero_false_hero_burst_slow:GetModifierMoveSpeedBonus_Percentage()
	return self:GetAbility():GetSpecialValueFor("burst_slow_pct")
end
function modifier_onelosthero_false_hero_burst_slow:GetEffectName()
	return "particles/generic_gameplay/generic_slowed_cold.vpcf"
end
function modifier_onelosthero_false_hero_burst_slow:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
-- Burst disarm
--------------------------------------------------------------------------------
modifier_onelosthero_false_hero_disarm = class({})
function modifier_onelosthero_false_hero_disarm:IsDebuff() return true end
function modifier_onelosthero_false_hero_disarm:IsPurgable() return true end
function modifier_onelosthero_false_hero_disarm:CheckState()
	return { [MODIFIER_STATE_DISARMED] = true }
end
