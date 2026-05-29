--[[
	OneLostHero — W: Blindspot Dagger
	Marks an enemy (and slows them). While marked, if OneLostHero attacks the target from
	the side or behind (within backstab_angle), an Echo appears behind the target, deals
	echo_strike_damage, and silences it. A swap window with that Echo opens. All values from KV.

	Swap (prototype): once the echo strike triggers we EndCooldown; recasting W during the
	swap window swaps with the Echo (target ignored, mana refunded) and starts the cooldown.
]]
local Echo = require("abilities/onelosthero/echo")

LinkLuaModifier("modifier_onelosthero_blindspot_dagger_mark", "abilities/onelosthero/blindspot_dagger", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_onelosthero_blindspot_dagger_silence", "abilities/onelosthero/blindspot_dagger", LUA_MODIFIER_MOTION_NONE)

onelosthero_blindspot_dagger = class({})

function onelosthero_blindspot_dagger:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_2
end

function onelosthero_blindspot_dagger:OnSpellStart()
	local caster = self:GetCaster()
	local now = GameRules:GetGameTime()

	-- ---- Swap branch (recast during window; target ignored) ----
	if self._swapUntil and now <= self._swapUntil and Echo:IsValid(self._echo) then
		if Echo:Swap(caster, self._echo) then
			caster:GiveMana(self._lastManaCost or 0)
			local echo = self._echo
			self._echo, self._swapUntil = nil, nil
			Timers:CreateTimer(0.05, function() if echo and not echo:IsNull() then Echo:Expire(echo) end end)
			self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
			return
		end
	end

	-- ---- Cast branch ----
	local target = self:GetCursorTarget()
	if not target or target:IsNull() then return end
	self._lastManaCost = self:GetManaCost(self:GetLevel() - 1)

	local daggerDamage = self:GetSpecialValueFor("dagger_damage")
	local markDuration = self:GetSpecialValueFor("mark_duration")

	-- Kez's Sai Talon Toss activity isn't exposed by the engine, so use the quick katana strike
	-- as the closest available, with the generic cast as fallback.
	Echo:PlayGesture(caster, { "ACT_DOTA_KEZ_KATANA_IMPALE_FAST", "ACT_DOTA_CAST_ABILITY_2" })
	ParticleManager:CreateParticle("particles/units/heroes/hero_phantom_assassin/phantom_assassin_stifling_dagger.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	caster:EmitSound("Hero_PhantomAssassin.Dagger.Target")

	ApplyDamage({
		victim = target, attacker = caster, damage = daggerDamage,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = self,
	})
	target:AddNewModifier(caster, self, "modifier_onelosthero_blindspot_dagger_mark", { duration = markDuration })
end

-- Called by the mark when a valid backstab attack lands.
function onelosthero_blindspot_dagger:TriggerEchoStrike(target)
	if not IsServer() then return end
	local caster = self:GetCaster()
	local echoDamage   = self:GetSpecialValueFor("echo_strike_damage")
	local silenceDur   = self:GetSpecialValueFor("silence_duration")
	local echoDuration = self:GetSpecialValueFor("echo_duration")
	local swapWin      = self:GetSpecialValueFor("swap_window")

	local behind = target:GetAbsOrigin() - target:GetForwardVector() * 100
	local echo = Echo:Create(caster, self, behind, {
		duration = math.max(echoDuration, swapWin), killable = false, canSwap = true, source = "blindspot_dagger",
	})
	if echo then
		echo:SetForwardVector(target:GetForwardVector())
		self._echo = echo
		self._swapUntil = GameRules:GetGameTime() + swapWin
		self:EndCooldown()
		Timers:CreateTimer(swapWin + 0.05, function()
			if self._swapUntil and GameRules:GetGameTime() > self._swapUntil then
				self._swapUntil = nil
				self._echo = nil
				if self:IsCooldownReady() then
					self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
				end
			end
		end)
	end

	ParticleManager:CreateParticle("particles/units/heroes/hero_riki/riki_backstab.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
	ApplyDamage({
		victim = target, attacker = caster, damage = echoDamage,
		damage_type = DAMAGE_TYPE_MAGICAL, ability = self,
	})
	target:AddNewModifier(caster, self, "modifier_onelosthero_blindspot_dagger_silence", { duration = silenceDur })
end

--------------------------------------------------------------------------------
-- Mark: slows the target and watches for a backstab attack from the caster.
--------------------------------------------------------------------------------
modifier_onelosthero_blindspot_dagger_mark = class({})
function modifier_onelosthero_blindspot_dagger_mark:IsDebuff() return true end
function modifier_onelosthero_blindspot_dagger_mark:IsPurgable() return true end
function modifier_onelosthero_blindspot_dagger_mark:OnCreated()
	self.triggered = false
end
function modifier_onelosthero_blindspot_dagger_mark:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end
function modifier_onelosthero_blindspot_dagger_mark:GetModifierMoveSpeedBonus_Percentage()
	return self:GetAbility():GetSpecialValueFor("slow_pct")
end
function modifier_onelosthero_blindspot_dagger_mark:OnAttackLanded(event)
	if not IsServer() then return end
	if self.triggered then return end
	local parent = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if event.attacker ~= caster then return end
	if event.target ~= parent then return end

	local angle = ability:GetSpecialValueFor("backstab_angle")
	if not Echo:IsBehindOrSide(caster, parent, angle) then return end

	self.triggered = true
	ability:TriggerEchoStrike(parent)
	self:Destroy()
end
function modifier_onelosthero_blindspot_dagger_mark:GetEffectName()
	return "particles/units/heroes/hero_riki/riki_smoke_screen_dustfield.vpcf"
end
function modifier_onelosthero_blindspot_dagger_mark:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end

--------------------------------------------------------------------------------
-- Silence
--------------------------------------------------------------------------------
modifier_onelosthero_blindspot_dagger_silence = class({})
function modifier_onelosthero_blindspot_dagger_silence:IsDebuff() return true end
function modifier_onelosthero_blindspot_dagger_silence:IsPurgable() return true end
function modifier_onelosthero_blindspot_dagger_silence:CheckState()
	return { [MODIFIER_STATE_SILENCED] = true }
end
function modifier_onelosthero_blindspot_dagger_silence:GetEffectName()
	return "particles/generic_gameplay/generic_silence.vpcf"
end
function modifier_onelosthero_blindspot_dagger_silence:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
