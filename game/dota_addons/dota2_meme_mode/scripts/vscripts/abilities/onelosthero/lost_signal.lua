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
		-- TEMP DIAGNOSTIC: list every Kez activity enum the engine exposes, so we can map the
		-- exact Echo Slash / Talon Toss / Raptor Dance cast animations. Remove once set.
		Timers:CreateTimer(2.0, function()
			local acts = {}
			for k, _ in pairs(_G) do
				if type(k) == "string" and (string.find(k, "ACT_DOTA_KEZ") or string.find(k, "RAPTOR") or string.find(k, "TALON") or string.find(k, "ECHO_SLASH")) then
					acts[#acts + 1] = k
				end
			end
			table.sort(acts)
			print("=== [OneLostHero] Kez activities (" .. #acts .. ") ===")
			for _, k in ipairs(acts) do print("   " .. k) end
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
