--[[
	OneLostHero — E: False Hero  (revised deception design)

	No-target. On cast: spawn an autonomous Echo that walks forward (in the hero's facing
	direction) attacking nearby creeps/heroes with reduced damage, while the real hero turns
	invisible. The Echo looks like the real hero.

	Recast routing (single button, state machine):
	  - idle    : a fresh cast creates the Echo + invis.
	  - swap    : an Echo is live -> recast swaps the hero with it (Echo destroyed safely,
	              NO explosion). Without Shard the sequence ends here. With Shard, a fading
	              Echo is left at the hero's original location -> mode "detonate".
	  - detonate: (Shard only) recast manually detonates the fading Echo (60% damage + Break).
	The Echo otherwise detonates (full damage + Break) if an enemy hero attacks it or it
	lives 10s without being swapped.

	Charges: native (1 base, +1 from the lvl20 talent). Because recasts (swap/detonate) reuse
	the cast button, every OnSpellStart spends a charge+mana; we refund those and "truly"
	consume exactly one charge when the whole sequence resolves (which starts the restore).

	All gameplay values come from KV.
]]
local Echo = require("abilities/onelosthero/echo")

LinkLuaModifier("modifier_onelosthero_false_hero_invis", "abilities/onelosthero/false_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_onelosthero_false_hero_break", "abilities/onelosthero/false_hero", LUA_MODIFIER_MOTION_NONE)

onelosthero_false_hero = class({})

function onelosthero_false_hero:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_3
end

function onelosthero_false_hero:GetIntrinsicModifierName()
	return nil
end

--------------------------------------------------------------------------------
-- Cooldown / charges (manual & reliable).
-- Base: a normal AbilityCooldown (24/21/18/15). Because recasts (swap/detonate) reuse the
-- cast button, the ability must stay castable while a sequence is live, so we EndCooldown
-- during it and only StartCooldown when the sequence resolves. The lvl20 talent grants a
-- 2nd "stored use": each completed sequence consumes one use and restores it after the
-- cooldown, so you can fire twice before waiting.
--------------------------------------------------------------------------------
function onelosthero_false_hero:_Cd()
	return self:GetCooldown(self:GetLevel() - 1)
end
function onelosthero_false_hero:_MaxCharges()
	local t = self:GetCaster():FindAbilityByName("special_bonus_unique_onelosthero_charges")
	return (t and t:GetLevel() > 0) and 2 or 1
end
function onelosthero_false_hero:_UpdateCastable()
	if self._mode ~= nil and self._mode ~= "idle" then
		self:EndCooldown()                       -- a recast (swap/detonate) is pending
	elseif (self._stored or self:_MaxCharges()) > 0 then
		self:EndCooldown()                       -- a stored use remains
	else
		self:StartCooldown(self:_Cd())           -- out of uses -> show the cooldown
	end
end
function onelosthero_false_hero:_ConsumeUse()
	if self._stored == nil then self._stored = self:_MaxCharges() end
	self._stored = math.max(0, self._stored - 1)
	Timers:CreateTimer(self:_Cd(), function()
		self._stored = math.min(self:_MaxCharges(), (self._stored or 0) + 1)
		self:_UpdateCastable()
	end)
end

--------------------------------------------------------------------------------
function onelosthero_false_hero:OnSpellStart()
	if self._stored == nil then self._stored = self:_MaxCharges() end
	local mode = self._mode or "idle"

	if mode == "swap" and Echo:IsValid(self._echo) then
		self:GetCaster():GiveMana(self._manaCost or 0) -- recast is free
		self:DoSwap()
		return
	elseif mode == "detonate" and Echo:IsValid(self._fadingEcho) then
		self:GetCaster():GiveMana(self._manaCost or 0)
		self:DoDetonateFading()
		return
	end

	-- Fresh cast (idle).
	self:CastFresh()
	self:_UpdateCastable() -- mode is now "swap" -> stays castable for the swap recast
end

function onelosthero_false_hero:CastFresh()
	local caster = self:GetCaster()
	self._manaCost = self:GetManaCost(self:GetLevel() - 1)

	local dir = caster:GetForwardVector()
	dir.z = 0
	dir = dir:Normalized()
	local startPos = caster:GetAbsOrigin()

	local echoDuration = self:GetSpecialValueFor("echo_duration")
	local invisDur     = self:GetSpecialValueFor("invis_duration")
	local dmgPct       = self:GetSpecialValueFor("echo_attack_damage_pct")
	local moveDist     = self:GetSpecialValueFor("echo_move_distance")
	-- Far waypoint in the facing direction; the Echo's modifier keeps re-issuing the
	-- attack-move toward it so it reliably advances even if the first order is dropped.
	local dest = startPos + dir * math.max(moveDist, 3000)

	-- real hero vanishes
	caster:AddNewModifier(caster, self, "modifier_onelosthero_false_hero_invis", { duration = invisDur })
	caster:EmitSound("Hero_Terrorblade.Reflection.Cast")

	-- A true illusion (Phantom-Lancer style) so it reads as the real hero. The illusion
	-- modifier handles its damage in/out; our tracking modifier rides along for swap +
	-- detonation + forward-drive. Deals echo_attack_damage_pct of the hero's damage.
	local echo = Echo:Create(caster, self, startPos, {
		illusion = true,
		outgoing_damage = dmgPct,
		incoming_damage = 100,
		duration = echoDuration,
		killable = true,
		canSwap = true,
		drive_forward = true,
		move_dest = dest,
		source = "false_hero",
		onExpire = function(u) self:OnEchoResolved(u:GetAbsOrigin(), 1.0) end,          -- 10s timeout -> detonate (teardown removes the unit)
		onDeath = function(_) self:OnEchoLostNoBlast() end,                            -- killed by non-hero -> no blast
		onHeroAttacked = function(u)                                                   -- enemy-hero attack -> detonate + remove
			self:OnEchoResolved(u:GetAbsOrigin(), 1.0)
			Echo:RemoveSafely(u)
		end,
	})

	if not echo then
		caster:GiveMana(self._manaCost or 0) -- nothing spawned; refund
		self._mode = "idle"
		self:_UpdateCastable()
		return
	end

	echo:SetForwardVector(dir)
	self._echo = echo
	self._mode = "swap"

	-- kick off movement immediately (the modifier re-issues thereafter)
	Timers:CreateTimer(0.03, function()
		if Echo:IsValid(echo) then
			ExecuteOrderFromTable({
				UnitIndex = echo:entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
				Position = dest,
				Queue = false,
			})
		end
	end)
end

-- Recast 1: swap with the live Echo.
function onelosthero_false_hero:DoSwap()
	local caster = self:GetCaster()
	local echo = self._echo
	local originalPos = Echo:Swap(caster, echo)
	if not originalPos then return end -- swap blocked (stunned/etc.); stay in swap mode

	Echo:RemoveSafely(echo) -- destroyed safely, no detonation
	self._echo = nil

	if caster:HasShard() then
		-- leave a fading Echo trap at the hero's original location
		local fadeDur = self:GetSpecialValueFor("fading_echo_duration")
		local fading = Echo:Create(caster, self, originalPos, {
			duration = fadeDur, killable = false, can_attack = false, canSwap = false,
			controllable = false, source = "false_hero_fading",
			onExpire = function(_) self:OnFadingExpired() end, -- recommended: expires without blast
		})
		if fading then
			self._fadingEcho = fading
			self._mode = "detonate"
			self:_UpdateCastable() -- stay castable to detonate the fading Echo
			return -- sequence not resolved yet
		end
	end

	-- no Shard (or fading failed): sequence done
	self._mode = "idle"
	self:_ConsumeUse()
	self:_UpdateCastable()
end

-- Recast 2 (Shard): manually detonate the fading Echo at reduced damage.
function onelosthero_false_hero:DoDetonateFading()
	local fading = self._fadingEcho
	local pct = self:GetSpecialValueFor("shard_detonation_pct") / 100
	if Echo:IsValid(fading) then
		self:Detonate(fading:GetAbsOrigin(), pct)
		Echo:RemoveSafely(fading)
	end
	self._fadingEcho = nil
	self._mode = "idle"
	self:_ConsumeUse()
	self:_UpdateCastable()
end

-- Echo reached a detonation condition (10s timeout or enemy-hero attack) without a swap.
function onelosthero_false_hero:OnEchoResolved(pos, mult)
	self:Detonate(pos, mult)
	self._echo = nil
	self._mode = "idle"
	self:_ConsumeUse()
	self:_UpdateCastable()
end

-- Echo died to non-hero damage (creeps/towers): no blast, just resolve.
function onelosthero_false_hero:OnEchoLostNoBlast()
	self._echo = nil
	self._mode = "idle"
	self:_ConsumeUse()
	self:_UpdateCastable()
end

-- Shard fading Echo expired naturally: disappears without detonation (recommended first impl).
function onelosthero_false_hero:OnFadingExpired()
	self._fadingEcho = nil
	self._mode = "idle"
	self:_ConsumeUse()
	self:_UpdateCastable()
end

-- AOE detonation: magical damage + Break.
function onelosthero_false_hero:Detonate(pos, mult)
	if not IsServer() then return end
	local caster = self:GetCaster()
	local dmg = self:GetSpecialValueFor("explosion_damage") * (mult or 1.0)
	local radius = self:GetSpecialValueFor("explosion_radius")
	local breakDur = self:GetSpecialValueFor("break_duration")

	-- Visible radial AOE blast (the old terrorblade_sunder is a unit-to-unit beam and renders
	-- nothing at a world point). doppelganger_aoe is a clear ground burst scaled to the radius.
	-- doppelganger_aoe loops, so it must be explicitly destroyed or it lingers forever.
	local p = ParticleManager:CreateParticle("particles/units/heroes/hero_phantom_lancer/phantom_lancer_doppelganger_aoe.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(p, 0, pos)
	ParticleManager:SetParticleControl(p, 1, Vector(radius, radius, radius))
	ParticleManager:SetParticleControl(p, 2, Vector(radius, radius, radius))
	ParticleManager:SetParticleControl(p, 3, pos)
	local p2 = ParticleManager:CreateParticle("particles/units/heroes/hero_spectre/spectre_desolate.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(p2, 0, pos)
	Timers:CreateTimer(1.5, function()
		ParticleManager:DestroyParticle(p, false);  ParticleManager:ReleaseParticleIndex(p)
		ParticleManager:DestroyParticle(p2, false); ParticleManager:ReleaseParticleIndex(p2)
	end)
	EmitSoundOnLocationWithCaster(pos, "Hero_PhantomLancer.Doppelganger", caster)

	for _, enemy in pairs(Echo:FindEnemiesInRadius(caster, pos, radius)) do
		if enemy and not enemy:IsNull() then
			ApplyDamage({ victim = enemy, attacker = caster, damage = dmg,
				damage_type = DAMAGE_TYPE_MAGICAL, ability = self })
			enemy:AddNewModifier(caster, self, "modifier_onelosthero_false_hero_break", { duration = breakDur })
		end
	end
end

--------------------------------------------------------------------------------
-- Invisibility on the real hero
--------------------------------------------------------------------------------
modifier_onelosthero_false_hero_invis = class({})
function modifier_onelosthero_false_hero_invis:IsPurgable() return false end
function modifier_onelosthero_false_hero_invis:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
		MODIFIER_EVENT_ON_ATTACK, -- attacking reveals the hero (and triggers Lost Signal)
	}
end
-- MODIFIER_STATE_INVISIBLE on its own frequently fails to hide the unit; the engine also
-- needs a non-zero invisibility level. Declaring both is the reliable invis pattern.
function modifier_onelosthero_false_hero_invis:GetModifierInvisibilityLevel()
	return 1.0
end
-- Attacking breaks invisibility immediately, even while the Echo is still alive. Casting
-- abilities (incl. the swap recast) does NOT break it, so you can swap from stealth.
function modifier_onelosthero_false_hero_invis:OnAttack(event)
	if not IsServer() then return end
	if event.attacker == self:GetParent() then
		self:Destroy()
	end
end
function modifier_onelosthero_false_hero_invis:CheckState()
	return { [MODIFIER_STATE_INVISIBLE] = true }
end
-- No follow particle on purpose: a vanish shouldn't leave a tell-tale effect on the hero.

--------------------------------------------------------------------------------
-- Break debuff
--------------------------------------------------------------------------------
modifier_onelosthero_false_hero_break = class({})
function modifier_onelosthero_false_hero_break:IsDebuff() return true end
function modifier_onelosthero_false_hero_break:IsPurgable() return true end
function modifier_onelosthero_false_hero_break:CheckState()
	return { [MODIFIER_STATE_PASSIVES_DISABLED] = true } -- Break
end
function modifier_onelosthero_false_hero_break:GetEffectName()
	return "particles/units/heroes/hero_spectre/spectre_desolate.vpcf"
end
function modifier_onelosthero_false_hero_break:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
