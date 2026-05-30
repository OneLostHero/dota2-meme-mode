--[[
	OneLostHero — Q: Second Stroke
	Dash-slash forward, damaging enemies in a line (slash_width wide) along the dash path, and
	leave an Echo at the start point. Then, within the swap window:
	  - If you DON'T swap, the Echo repeats the strike: it dashes forward and strikes again for
	    reduced damage, then vanishes.
	  - If you recast to SWAP, you trade places with the Echo, then slash back toward where you
	    were (reduced damage). The Echo is consumed.
	All values from KV.

	Cooldown: kept castable during the swap window via EndCooldown so the recast works; the
	real cooldown starts on swap, or when the Echo finishes its repeat strike.
]]
local Echo = require("abilities/onelosthero/echo")

onelosthero_second_stroke = class({})

function onelosthero_second_stroke:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_1
end

-- Trading places with the Echo during the swap window is FREE: only the initial slash costs
-- mana. Returning 0 while a swap is pending means the recast neither requires nor spends mana.
function onelosthero_second_stroke:GetManaCost(iLevel)
	if self._swapUntil and Echo:IsValid(self._echo) and GameRules:GetGameTime() <= self._swapUntil then
		return 0
	end
	return self:_BaseManaCost(iLevel)
end

-- Configured AbilityManaCost from KV (cached), so GetManaCost can return the normal cost.
function onelosthero_second_stroke:_BaseManaCost(iLevel)
	if not self._manaCosts then
		self._manaCosts = {}
		local kv = self:GetAbilityKeyValues() or {}
		local raw = kv.AbilityManaCost
		if type(raw) == "number" then raw = tostring(raw) end
		if type(raw) == "string" then
			for tok in string.gmatch(raw, "%S+") do
				self._manaCosts[#self._manaCosts + 1] = tonumber(tok) or 0
			end
		end
	end
	if iLevel == nil or iLevel < 0 then iLevel = self:GetLevel() - 1 end
	local idx = math.max(1, iLevel + 1)
	return self._manaCosts[idx] or self._manaCosts[#self._manaCosts] or 0
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
	local width   = self:GetSpecialValueFor("slash_width")
	local damage  = self:GetSpecialValueFor("damage")
	local echoPct = self:GetSpecialValueFor("echo_damage_pct")

	-- ---- Swap branch: recast during the window -> trade places, then slash back toward your old spot ----
	if self._swapUntil and now <= self._swapUntil and Echo:IsValid(self._echo) then
		local echo = self._echo
		local echoPos = echo:GetAbsOrigin()
		local heroOrigin = Echo:Swap(caster, echo) -- hero moves to echoPos; returns hero's pre-swap pos
		if heroOrigin then
			-- swap is free (GetManaCost returns 0 during the window), so no refund needed
			self._echo, self._swapUntil = nil, nil
			local dir = (heroOrigin - echoPos); dir.z = 0
			if dir:Length2D() > 1 then caster:SetForwardVector(dir:Normalized()) end
			Echo:PlayGesture(caster, { "ACT_DOTA_ATTACK", "ACT_DOTA_CAST_ABILITY_1" })
			-- slash back along the line from where you reappeared toward your old spot
			self:LineVFX(echoPos, heroOrigin, width)
			self:DamageLine(caster, echoPos, heroOrigin, width, damage * (echoPct / 100))
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
	local swapWin   = self:GetSpecialValueFor("swap_window")
	local dashSpeed = self:GetSpecialValueFor("dash_speed")
	local endPos = startPos + dir * distance

	-- hero Echo-Slash cast animation + visible slash, radius damage, then dash forward
	caster:StartGesture(ACT_DOTA_CAST_ABILITY_1)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
	self:LineVFX(startPos, endPos, width)
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
		echo:EmitSound("Hero_VoidSpirit.AstralStep.Cast")
		self:LineVFX(startPos, endPos, width)
		self:DamageLine(caster, startPos, endPos, width, damage * (echoPct / 100))
		self:DashUnit(echo, startPos, endPos, dashSpeed, function()
			if echo and not echo:IsNull() then Echo:Expire(echo) end
		end)
		if self:IsCooldownReady() then self:StartCooldown(cd) end
	end)
end

-- Visible slash that covers the line from `fromPos` to `toPos` at the given width: blade
-- slashes laid down in three lanes (center + both edges) along the path so the full hit
-- corridor reads. Brief + explicitly destroyed so nothing lingers.
function onelosthero_second_stroke:LineVFX(fromPos, toPos, width)
	local dir = (toPos - fromPos); dir.z = 0
	local len = dir:Length2D()
	if len < 1 then dir = Vector(1, 0, 0); len = 1 else dir = dir:Normalized() end
	local perp = Vector(-dir.y, dir.x, 0)
	local lanes = { -width * 0.33, 0, width * 0.33 }
	local spacing = 150
	local n = math.max(1, math.floor(len / spacing))

	local fx = {}
	for i = 0, n do
		local base = fromPos + dir * (len * (i / n))
		for _, off in ipairs(lanes) do
			local s = ParticleManager:CreateParticle("particles/units/heroes/hero_riki/riki_backstab.vpcf", PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(s, 0, base + perp * off)
			ParticleManager:SetParticleControlForward(s, 0, dir)
			fx[#fx + 1] = s
		end
	end

	Timers:CreateTimer(0.5, function()
		for _, p in ipairs(fx) do
			ParticleManager:DestroyParticle(p, false); ParticleManager:ReleaseParticleIndex(p)
		end
	end)
end

-- Damage every enemy within the rectangle from `fromPos` to `toPos` (full width = `width`;
-- FindUnitsInLine takes the half-width / perpendicular distance, hence width * 0.5).
function onelosthero_second_stroke:DamageLine(caster, fromPos, toPos, width, damage)
	for _, enemy in pairs(Echo:FindEnemiesInLine(caster, fromPos, toPos, width * 0.5)) do
		if enemy and not enemy:IsNull() then
			ApplyDamage({
				victim = enemy, attacker = caster, damage = damage,
				damage_type = DAMAGE_TYPE_PHYSICAL, ability = self,
			})
		end
	end
end
