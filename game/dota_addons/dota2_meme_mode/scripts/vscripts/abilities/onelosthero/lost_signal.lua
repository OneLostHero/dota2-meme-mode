--[[
	OneLostHero — Innate: Lost Signal
	Breaking invisibility / emerging unseen arms a window; the next strike on an enemy
	deals bonus damage (and a brief Echo flourish), then goes on an internal cooldown.
	All values from KV.
]]
local Echo = require("abilities/onelosthero/echo")

LinkLuaModifier("modifier_onelosthero_lost_signal", "abilities/onelosthero/lost_signal", LUA_MODIFIER_MOTION_NONE)

onelosthero_lost_signal = class({})

function onelosthero_lost_signal:GetIntrinsicModifierName()
	return "modifier_onelosthero_lost_signal"
end

--------------------------------------------------------------------------------
modifier_onelosthero_lost_signal = class({})

function modifier_onelosthero_lost_signal:IsHidden() return true end
function modifier_onelosthero_lost_signal:IsPurgable() return false end

function modifier_onelosthero_lost_signal:OnCreated()
	self.readyUntil = 0
	self.cooldownUntil = 0
end

function modifier_onelosthero_lost_signal:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_BREAK_INVISIBILITY,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_onelosthero_lost_signal:OnBreakInvisibility()
	if not IsServer() then return end
	local ability = self:GetAbility()
	if not ability then return end
	local window = ability:GetSpecialValueFor("trigger_window")
	self.readyUntil = GameRules:GetGameTime() + window
end

function modifier_onelosthero_lost_signal:OnAttackLanded(event)
	if not IsServer() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()
	if not ability then return end
	if event.attacker ~= parent then return end

	local target = event.target
	if not target or target:IsNull() or not target:IsAlive() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end

	local now = GameRules:GetGameTime()
	if now > self.readyUntil then return end
	if now < self.cooldownUntil then return end

	local bonus = ability:GetSpecialValueFor("bonus_damage")
	local icd   = ability:GetSpecialValueFor("internal_cooldown")

	ApplyDamage({
		victim       = target,
		attacker     = parent,
		damage       = bonus,
		damage_type  = DAMAGE_TYPE_PHYSICAL,
		ability      = ability,
	})

	self.readyUntil = 0
	self.cooldownUntil = now + icd

	-- brief Echo flourish behind the target (visual + reduced echo strike)
	local echoPct = ability:GetSpecialValueFor("echo_damage_pct")
	local echoDur = ability:GetSpecialValueFor("echo_duration")
	local behind = target:GetAbsOrigin() - target:GetForwardVector() * 90
	local echo = Echo:Create(parent, ability, behind, {
		duration = echoDur, killable = false, canSwap = false, source = "lost_signal",
	})
	if echo then
		echo:SetForwardVector((target:GetAbsOrigin() - behind):Normalized())
		ParticleManager:CreateParticle("particles/units/heroes/hero_riki/riki_backstab.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
		ApplyDamage({
			victim = target, attacker = parent,
			damage = bonus * (echoPct / 100),
			damage_type = DAMAGE_TYPE_PHYSICAL, ability = ability,
		})
	end
end
