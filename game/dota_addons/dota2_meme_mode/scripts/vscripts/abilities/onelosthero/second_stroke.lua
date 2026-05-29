--[[
	OneLostHero — Q: Second Stroke
	Dash-slash forward, damaging enemies in a line. An Echo spawns at the start point and,
	after echo_delay, repeats the slash at reduced damage. During swap_window, recast to
	swap places with the Echo. All values from KV.

	Recast-to-swap on a non-toggle ability (prototype approach, per brief): after the first
	cast we EndCooldown so the ability is immediately re-castable; a recast within the swap
	window performs the swap (mana refunded) and then starts the real cooldown. If the window
	lapses unused, the real cooldown starts then.
]]
local Echo = require("abilities/onelosthero/echo")

onelosthero_second_stroke = class({})

function onelosthero_second_stroke:GetCastAnimation()
	return ACT_DOTA_CAST_ABILITY_1
end

function onelosthero_second_stroke:OnSpellStart()
	local caster = self:GetCaster()
	local now = GameRules:GetGameTime()

	-- ---- Swap branch: recast during the window with a live Echo ----
	if self._swapUntil and now <= self._swapUntil and Echo:IsValid(self._echo) then
		if Echo:Swap(caster, self._echo) then
			caster:GiveMana(self._lastManaCost or 0) -- swap recast is free
			local echo = self._echo
			self._echo, self._swapUntil = nil, nil
			Timers:CreateTimer(0.05, function() if echo and not echo:IsNull() then Echo:Expire(echo) end end)
			self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
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

	local distance = self:GetSpecialValueFor("slash_distance")
	local width    = self:GetSpecialValueFor("slash_width")
	local damage   = self:GetSpecialValueFor("damage")
	local echoDelay = self:GetSpecialValueFor("echo_delay")
	local echoPct  = self:GetSpecialValueFor("echo_damage_pct")
	local echoDur  = self:GetSpecialValueFor("echo_duration")
	local swapWin  = self:GetSpecialValueFor("swap_window")
	local endPos = startPos + dir * distance

	self._lastManaCost = self:GetManaCost(self:GetLevel() - 1)

	-- slash VFX + sound
	ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_blade_fury.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	caster:EmitSound("Hero_VoidSpirit.AstralStep.Cast")

	-- first slash damage (start -> end)
	self:DamageLine(caster, startPos, endPos, width, damage)

	-- dash/reposition the caster forward (prototype: instant, clamped to clear space)
	caster:SetAbsOrigin(endPos)
	FindClearSpaceForUnit(caster, endPos, false)
	caster:SetForwardVector(dir)

	-- Echo at the start, repeats the slash after the delay
	local echo = Echo:Create(caster, self, startPos, {
		duration = math.max(echoDur, swapWin), killable = false, canSwap = true, source = "second_stroke",
	})
	if echo then
		echo:SetForwardVector(dir)
		self._echo = echo
		self._swapUntil = now + swapWin
		local echoStart = startPos
		local echoEnd = endPos
		Timers:CreateTimer(echoDelay, function()
			if Echo:IsValid(echo) then
				ParticleManager:CreateParticle("particles/units/heroes/hero_juggernaut/juggernaut_blade_fury.vpcf", PATTACH_ABSORIGIN_FOLLOW, echo)
				self:DamageLine(caster, echoStart, echoEnd, width, damage * (echoPct / 100))
			end
		end)
		-- allow recast-to-swap during the window
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
	else
		self:StartCooldown(self:GetCooldown(self:GetLevel() - 1))
	end
end

function onelosthero_second_stroke:DamageLine(caster, startPos, endPos, width, damage)
	local hit = Echo:FindEnemiesInLine(caster, startPos, endPos, width)
	for _, enemy in pairs(hit) do
		if enemy and not enemy:IsNull() then
			ApplyDamage({
				victim = enemy, attacker = caster, damage = damage,
				damage_type = DAMAGE_TYPE_PHYSICAL, ability = self,
			})
		end
	end
end
