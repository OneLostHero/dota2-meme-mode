--[[
  meme_diag.lua  —  on-demand stutter profiler (server-side, dormant until started)

  WHY: "fps fine but everyone stutters" = the server tick is hitching. The usual cause in
  this mod is a per-frame Lua cost: an engine filter that fires thousands of times a frame,
  or a runaway/leaking timer. There is no sub-ms Lua clock here, so this measures FREQUENCY
  (calls/sec per filter) + active-timer count, which is what reveals a runaway path.

  USAGE (in the in-game console — tools mode, or host with sv_cheats):
      meme_diag_start     -> every 1s prints per-filter call counts + active timers
      meme_diag_stop      -> restores original filters, stops printing

  Read the output: one filter with a huge number (tens of thousands/sec), or timers_active
  climbing without bound, is your culprit. If ALL counts are small and steady, the stutter is
  NOT server-Lua -> use the engine profiler (see cl_showfps / vprof notes from the chat).

  This file only registers two console commands at load; it does nothing (zero overhead)
  until you type meme_diag_start. Safe to leave in; remove the require in addon_game_mode.lua
  when you're done.
]]

MemeDiag = MemeDiag or {}
MemeDiag.active = false
MemeDiag.counts = MemeDiag.counts or {}
MemeDiag._orig = MemeDiag._orig or {}

-- The filter dispatchers registered by PluginSystem:SetFilters().
local FILTERS = {
  "AbilityTuningValueFilter", "BountyRunePickupFilter", "DamageFilter", "ExecuteOrderFilter",
  "HealingFilter", "ItemAddedToInventoryFilter", "ModifierGainedFilter", "ModifyExperienceFilter",
  "ModifyGoldFilter", "RuneSpawnFilter", "TrackingProjectileFilter",
}

local function count_active_timers()
  local n = 0
  if Timers and Timers.timers then
    for _ in pairs(Timers.timers) do n = n + 1 end
  end
  return n
end

function MemeDiag:Dump()
  local parts = {}
  for _, name in ipairs(FILTERS) do
    local c = self.counts[name] or 0
    if c > 0 then table.insert(parts, name .. "=" .. c) end
    self.counts[name] = 0
  end
  print(string.format("[MemeDiag] last 1s | timers_active=%d | %s",
    count_active_timers(),
    (#parts > 0 and table.concat(parts, "  ") or "(no filter calls)")))
end

function MemeDiag:Start()
  if self.active then print("[MemeDiag] already running") return end
  if not PluginSystem then print("[MemeDiag] PluginSystem not ready (start after the game is in progress)") return end

  -- Wrap each filter dispatcher with a counter, preserving the original.
  for _, name in ipairs(FILTERS) do
    local orig = self._orig[name] or PluginSystem[name]
    if type(orig) == "function" then
      self._orig[name] = orig
      self.counts[name] = 0
      PluginSystem[name] = function(...)
        MemeDiag.counts[name] = (MemeDiag.counts[name] or 0) + 1
        return orig(...)
      end
    end
  end
  -- Re-register so the engine calls the wrapped versions (SetFilters captured references).
  PluginSystem:SetFilters()

  self.active = true
  Timers:CreateTimer("meme_diag_dump", { endTime = 1.0, callback = function()
    if not MemeDiag.active then return end
    MemeDiag:Dump()
    return 1.0
  end })
  print("[MemeDiag] STARTED — per-second filter/timer counts will print below. 'meme_diag_stop' to end.")
end

function MemeDiag:Stop()
  if not self.active then print("[MemeDiag] not running") return end
  self.active = false
  for name, orig in pairs(self._orig) do
    PluginSystem[name] = orig
  end
  self._orig = {}
  if PluginSystem then PluginSystem:SetFilters() end
  print("[MemeDiag] STOPPED — original filters restored.")
end

if Convars and not MemeDiag._registered then
  MemeDiag._registered = true
  Convars:RegisterCommand("meme_diag_start", function() MemeDiag:Start() end,
    "Start the meme-mode server-side filter/timer profiler (prints calls/sec).", 0)
  Convars:RegisterCommand("meme_diag_stop", function() MemeDiag:Stop() end,
    "Stop the meme-mode profiler and restore filters.", 0)
  print("[MemeDiag] loaded — type 'meme_diag_start' in console once in-game.")
end
