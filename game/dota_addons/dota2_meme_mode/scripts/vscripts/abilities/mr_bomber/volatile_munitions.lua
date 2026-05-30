--[[
	Mr. Bomber — Innate: Volatile Munitions

	A hidden intrinsic passive that makes his demolitions kit better:
	  - +bonus_spell_amp% to all his spell damage (so Remote Mines and Meat Hook hit harder).
	  - -mine_manacost_reduction_pct% mana cost on Remote Mines only.
	  - -mine_cooldown_reduction_pct% cooldown on Remote Mines only (lay mines faster, so a
	    bigger pile stays on the field — the robust stand-in for "+2 max mines", which isn't
	    reachable on the borrowed techies_remote_mines ability from a modifier).

	All effects use standard modifier properties; the two mine-specific ones are gated by the
	triggering ability's name so they don't touch his other spells. All values from KV.
]]
LinkLuaModifier("modifier_mr_bomber_volatile_munitions", "abilities/mr_bomber/volatile_munitions", LUA_MODIFIER_MOTION_NONE)

mr_bomber_volatile_munitions = class({})

function mr_bomber_volatile_munitions:GetIntrinsicModifierName()
	return "modifier_mr_bomber_volatile_munitions"
end

--------------------------------------------------------------------------------
local MINE_ABILITY = "techies_remote_mines"

modifier_mr_bomber_volatile_munitions = class({})

function modifier_mr_bomber_volatile_munitions:IsHidden() return true end
function modifier_mr_bomber_volatile_munitions:IsPurgable() return false end

function modifier_mr_bomber_volatile_munitions:OnCreated()
	local ability = self:GetAbility()
	self.spellAmp   = ability and ability:GetSpecialValueFor("bonus_spell_amp") or 0
	self.manacostCut = ability and ability:GetSpecialValueFor("mine_manacost_reduction_pct") or 0
	self.cooldownCut = ability and ability:GetSpecialValueFor("mine_cooldown_reduction_pct") or 0
end

-- Recompute from KV if the ability is refreshed (cheap, keeps values authoritative).
modifier_mr_bomber_volatile_munitions.OnRefresh = modifier_mr_bomber_volatile_munitions.OnCreated

function modifier_mr_bomber_volatile_munitions:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_MANACOST_PERCENTAGE,
		MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
	}
end

function modifier_mr_bomber_volatile_munitions:GetModifierSpellAmplify_Percentage()
	return self.spellAmp
end

-- MANACOST_PERCENTAGE returns a reduction (positive value lowers the cost). Gate to mines only.
function modifier_mr_bomber_volatile_munitions:GetModifierPercentageManacost(event)
	if event and event.ability and event.ability:GetAbilityName() == MINE_ABILITY then
		return self.manacostCut
	end
	return 0
end

-- COOLDOWN_PERCENTAGE returns a reduction (positive value lowers the cooldown). Gate to mines only.
function modifier_mr_bomber_volatile_munitions:GetModifierPercentageCooldown(event)
	if event and event.ability and event.ability:GetAbilityName() == MINE_ABILITY then
		return self.cooldownCut
	end
	return 0
end
