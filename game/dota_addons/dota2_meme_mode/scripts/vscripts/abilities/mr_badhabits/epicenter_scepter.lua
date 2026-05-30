--[[
	Mr. BadHabits — Aghanim's Scepter: Epicenter

	A hidden intrinsic passive that upgrades the borrowed sandking_epicenter ONLY while the hero
	holds an Aghanim's Scepter. Epicenter has no native Scepter (Sand King's real Aghs is on Sand
	Storm, which this hero lacks) and reads pulse/radius/damage from KV at cast time, so we can't
	add a scepter via KV without mutating the shared ability. Instead, two robust effects:
	  - -scepter_cooldown_reduction_pct% Epicenter cooldown (per-ability gated COOLDOWN_PERCENTAGE).
	  - +scepter_bonus_damage_pct% Epicenter damage: when an Epicenter pulse damages an enemy and
	    we hold a Scepter, deal a bonus chunk of magical damage. A re-entrancy guard stops the
	    bonus (which is also magical) from triggering itself.

	All values from KV. Mirrors the established custom-hero intrinsic-modifier pattern
	(see abilities/mr_bomber/volatile_munitions and the frankenstein aghs plan).
]]
LinkLuaModifier("modifier_mr_badhabits_epicenter_scepter", "abilities/mr_badhabits/epicenter_scepter", LUA_MODIFIER_MOTION_NONE)

mr_badhabits_epicenter_scepter = class({})

function mr_badhabits_epicenter_scepter:GetIntrinsicModifierName()
	return "modifier_mr_badhabits_epicenter_scepter"
end

--------------------------------------------------------------------------------
local EPICENTER_ABILITY = "sandking_epicenter"

modifier_mr_badhabits_epicenter_scepter = class({})

function modifier_mr_badhabits_epicenter_scepter:IsHidden() return true end
function modifier_mr_badhabits_epicenter_scepter:IsPurgable() return false end

function modifier_mr_badhabits_epicenter_scepter:OnCreated()
	local ability = self:GetAbility()
	self.cdrPct   = ability and ability:GetSpecialValueFor("scepter_cooldown_reduction_pct") or 0
	self.dmgPct   = ability and ability:GetSpecialValueFor("scepter_bonus_damage_pct") or 0
	self._reentry = false
end

modifier_mr_badhabits_epicenter_scepter.OnRefresh = modifier_mr_badhabits_epicenter_scepter.OnCreated

function modifier_mr_badhabits_epicenter_scepter:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

-- COOLDOWN_PERCENTAGE returns a reduction (positive lowers cooldown). Gate to Epicenter + Scepter.
function modifier_mr_badhabits_epicenter_scepter:GetModifierPercentageCooldown(event)
	if not self:GetParent():HasScepter() then return 0 end
	if event and event.ability and event.ability:GetAbilityName() == EPICENTER_ABILITY then
		return self.cdrPct
	end
	return 0
end

function modifier_mr_badhabits_epicenter_scepter:OnTakeDamage(kv)
	if not IsServer() then return end
	if self._reentry then return end
	local me = self:GetParent()
	if kv.attacker ~= me then return end
	if not me:HasScepter() then return end
	if not kv.inflictor or kv.inflictor:GetAbilityName() ~= EPICENTER_ABILITY then return end

	local victim = kv.unit
	if not victim or victim:IsNull() or not victim:IsAlive() then return end
	if victim:GetTeamNumber() == me:GetTeamNumber() then return end

	local bonus = (kv.original_damage or kv.damage or 0) * (self.dmgPct / 100.0)
	if bonus <= 0 then return end

	self._reentry = true
	ApplyDamage({
		victim = victim, attacker = me, damage = bonus,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility(),
	})
	self._reentry = false
end
