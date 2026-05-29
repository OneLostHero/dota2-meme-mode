--[[
	OneLostHero — Q: Second Stroke
	Dash-slash forward, damaging enemies in a line, and leave an Echo at the start point.
	Then, within the swap window:
	  - If you DON'T swap, the Echo repeats the strike: it dashes forward along the same line
	    and deals reduced damage, then vanishes.
	  - If you recast to SWAP, you trade places with the Echo (the move in reverse) and the
	    Echo is consumed without striking.
	All values from KV.

	Cooldown: kept castable during the swap window via EndCooldown so the recast works; the
	real cooldown starts on swap, or when the Echo finishes its repeat strike.
]]
local Echo = require("abilities/onelosthero/echo")

onelosthero_second_stroke = class({})

function onelosthero_second_stroke:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_1
end

-- Smoothly slide a unit from `from` to `to` at `speed` (units/sec); calls onDone at the end.
function onelosthero_second_stroke:DashUnit(unit, from, to, speed, onDone)
	local dist = (to - from):Length2D()
	local steps = math.max(1, math.floor((dist / math.max(speed, 1)) / 0.03))
	local i = 0
	Timers:CreateTimer(0, function()
		if not Echo:IsValid(unit) then return nil end
		i = i + 1
		local frac = math.min(1, i / steps)
		unit:SetAbsOrigin(from + (to - from) * frac)
		if frac >= 1 then
			if onDone then onDone() end
			return nil
		end
		return 0.03
	end)
end

function onelosthero_second_stroke:OnSpellStart()
	local caster = self:GetCaster()
	local now = GameRules:GetGameTime()
	local cd = self:GetCooldown(self:GetLevel() - 1)

	-- ---- Swap branch: recast during the window -> trade places, consume Echo, no repeat ----
	if self._swapUntil and now <= self._swapUntil and Echo:IsValid(self._echo) then
		if Echo:Swap(caster, self._echo) then
			caster:GiveMana(self._lastManaCost or 0) -- swap recast is free
			local echo = self._echo
			self._echo, self._swapUntil = nil, nil
			Timers:CreateTimer(0.05, function() if echo and not echo:IsNull() then Echo:Expire(echo) end end)
			self:StartCooldown(cd)
			return
		end
	end

	-- ---- Slash branch ----
	local startPos = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()
	local dir = (point - startPos)
	dir.z = 0
	if dir:Length2D() < 1 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()

	local distance  = self:GetSpecialValueFor("slash_distance")
	local width     = self:GetSpecialValueFor("slash_width")
	local damage    = self:GetSpecialValueFor("damage")
	local echoPct   = self:GetSpecialValueFor("echo_damage_pct")
	local swapWin   = self:GetSpecialValueFor("swap_window")
	local dashSpeed = self:GetSpecialValueFor("dash_speed")
	local endPos = startPos + dir * distance
	self._lastManaCost = self:GetManaCost(self:GetLevel() - 1)

	-- hero slash VFX + sound, line damage, then dash forward
	ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_blade_fury.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
	self:DamageLine(caster, startPos, endPos, width, damage)
	caster:SetAbsOrigin(endPos)
	FindClearSpaceForUnit(caster, endPos, false)
	caster:SetForwardVector(dir)

	-- Echo at the start point, facing the slash direction. Lives a bit past the window so our
	-- timer (not the modifier) controls when it strikes/expires.
	local echo = Echo:Create(caster, self, startPos, {
		duration = swapWin + 2.0, killable = false, canSwap = true, source = "second_stroke",
	})
	if not echo then
		self:StartCooldown(cd)
		return
	end
	echo:SetForwardVector(dir)
	self._echo = echo
	self._swapUntil = now + swapWin
	self:EndCooldown() -- allow recast-to-swap during the window

	-- At the end of the window: if the player never swapped, the Echo repeats the strike.
	Timers:CreateTimer(swapWin, function()
		if self._echo ~= echo or not Echo:IsValid(echo) then return end -- swapped/gone already
		self._echo = nil
		self._swapUntil = nil
		ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_blade_fury.vpcf", PATTACH_ABSORIGIN_FOLLOW, echo)
		echo:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
		self:DamageLine(caster, startPos, endPos, width, damage * (echoPct / 100))
		self:DashUnit(echo, startPos, endPos, dashSpeed, function()
			if echo and not echo:IsNull() then Echo:Expire(echo) end
		end)
		if self:IsCooldownReady() then self:StartCooldown(cd) end
	end)
end

function onelosthero_second_stroke:DamageLine(caster, startPos, endPos, width, damage)
	for _, enemy in pairs(Echo:FindEnemiesInLine(caster, startPos, endPos, width)) do
		if enemy and not enemy:IsNull() then
			ApplyDamage({
				victim = enemy, attacker = caster, damage = damage,
				damage_type = DAMAGE_TYPE_PHYSICAL, ability = self,
			})
		end
	end
end
