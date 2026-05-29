--[[
	OneLostHero — Innate: Lost Signal
	Emerging from invisibility arms a window; the next strike on an enemy deals bonus damage
	(plus a brief Echo flourish), then goes on an internal cooldown.

	We do NOT rely on the engine's ON_BREAK_INVISIBILITY event — it doesn't fire when our
	custom Lua invisibility (False Hero / Vanishing Point) is removed. Instead the intrinsic
	modifier polls the hero's invisibility state and arms on an invisible -> visible transition,
	which catches every source. All values from KV.
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
	self.wasInvisible = false
	if IsServer() then
		self:StartIntervalThink(0.1)
		-- TEMP DIAGNOSTIC: list the hero's actual ability slots a moment after spawn so we can
		-- see whether the custom talents (slots 10-17) loaded or got replaced. Remove once the
		-- talent tree is confirmed. (Also: if this never prints, the innate modifier isn't
		-- applying — itself a clue.)
		local h = self:GetParent()
		Timers:CreateTimer(2.0, function()
			if not h or h:IsNull() then return end
			print("=== [OneLostHero] ability/talent slots ===")
			for i = 0, 17 do
				local a = h:GetAbilityByIndex(i)
				if a then print(string.format("  slot %d: %s (lvl %d)", i, a:GetAbilityName(), a:GetLevel())) end
			end
			-- Is the talents file itself loadable + does it define our talents?
			local kv = LoadKeyValues("scripts/npc/abilities/onelosthero_talents.txt")
			if kv and kv["DOTAAbilities"] then
				for k, _ in pairs(kv["DOTAAbilities"]) do print("  talents.txt defines: " .. tostring(k)) end
			elseif kv then
				for k, _ in pairs(kv) do print("  talents.txt ROOT key: " .. tostring(k)) end
			else
				print("  talents.txt FAILED to load (nil)")
			end
			-- Does the hero actually have each talent ability by name?
			for _, n in ipairs({
				"special_bonus_unique_onelosthero_invis",
				"special_bonus_unique_onelosthero_charges",
			}) do
				print("  HasAbility(" .. n .. ") = " .. tostring(h:HasAbility(n)))
			end
			print("=== [OneLostHero] end ===")
		end)
	end
end

function modifier_onelosthero_lost_signal:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_BREAK_INVISIBILITY, -- still handled in case the engine does fire it
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
end

function modifier_onelosthero_lost_signal:Arm()
	local ability = self:GetAbility()
	if not ability then return end
	self.readyUntil = GameRules:GetGameTime() + ability:GetSpecialValueFor("trigger_window")
end

-- Detect invisible -> visible: that's "emerging unseen", which arms the strike.
function modifier_onelosthero_lost_signal:OnIntervalThink()
	if not IsServer() then return end
	local parent = self:GetParent()
	local invis = parent:IsInvisible()
	if self.wasInvisible and not invis then
		self:Arm()
	end
	self.wasInvisible = invis
end

function modifier_onelosthero_lost_signal:OnBreakInvisibility()
	if not IsServer() then return end
	self:Arm()
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
		victim = target, attacker = parent, damage = bonus,
		damage_type = DAMAGE_TYPE_PHYSICAL, ability = ability,
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
			victim = target, attacker = parent, damage = bonus * (echoPct / 100),
			damage_type = DAMAGE_TYPE_PHYSICAL, ability = ability,
		})
	end
end
