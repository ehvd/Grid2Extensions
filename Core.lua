-- Grid2Extensions: shared helpers for the modules (Casts.lua, SummonRequest.lua, ...).
-- Every file of the addon receives the same private namespace table as its second vararg.

local _, ns = ...

-- Grid2Options is load-on-demand: run `fn` once it is loaded (immediately if it already is). Modules use this to
-- register their option pages and categories.
local pending
function ns.OnGrid2Options(fn)
	if Grid2Options then return fn() end
	if not pending then
		pending = {}
		local loader = CreateFrame("Frame")
		loader:RegisterEvent("ADDON_LOADED")
		loader:SetScript("OnEvent", function(self, _, addon)
			if addon == "Grid2Options" and Grid2Options then
				self:UnregisterEvent("ADDON_LOADED")
				for _, f in ipairs(pending) do f() end
				pending = nil
			end
		end)
	end
	pending[#pending + 1] = fn
end

---------------------------------------------------------------------------------------------------------------
-- Timed statuses: an indicator that is switched on for a unit (by GUID) and, optionally, expires by itself.
-- Used by the cast and request statuses. A status injects this mixin and sets `self.active = {}` and `self.color`.
---------------------------------------------------------------------------------------------------------------

local Grid2 = Grid2
if not Grid2 then return end

local GetTime, UnitGUID, C_Timer = GetTime, UnitGUID, C_Timer
local pairs, wipe = pairs, wipe

local tracked = {} -- [status] = true, timed statuses that currently have indicators
local frame = CreateFrame("Frame")

local function UpdateEvents()
	if next(tracked) then
		frame:RegisterEvent("GROUP_ROSTER_UPDATE")
		frame:RegisterEvent("PLAYER_LOGOUT")
	else
		frame:UnregisterAllEvents()
	end
end

frame:SetScript("OnEvent", function(_, event)
	for status in pairs(tracked) do
		if event == "GROUP_ROSTER_UPDATE" then status:Prune() else wipe(status.active) end
	end
end)

local Timed = {}
ns.Timed = Timed

-- Call from OnEnable / OnDisable.
function Timed:Track()
	tracked[self] = true
	UpdateEvents()
end

function Timed:Untrack()
	tracked[self] = nil
	wipe(self.active) -- pending timers find no matching entry and do nothing
	UpdateEvents()
end

-- Switch the status on for `guid` (shown on `unit`'s frame). duration nil or 0: stays until Clear() is called.
-- Entries are keyed by GUID, not unit, because unit tokens change when the roster shuffles. Each timer only clears
-- the entry it created, so a second trigger refreshes the status instead of being cut short by the first timer.
function Timed:Trigger(guid, unit, duration)
	local entry = {}
	if duration and duration > 0 then
		entry.duration = duration
		entry.expires = GetTime() + duration
		C_Timer.After(duration, function()
			if self.active[guid] == entry then self:Clear(guid) end
		end)
	end
	self.active[guid] = entry
	self:UpdateIndicators(unit)
end

function Timed:Clear(guid)
	if not self.active[guid] then return end
	self.active[guid] = nil
	local unit = Grid2:GetUnitOfGUID(guid)
	if unit then self:UpdateIndicators(unit) end
end

-- Drop entries of players who left the group; their frames are gone, so no indicator update is needed.
function Timed:Prune()
	for guid in pairs(self.active) do
		if not Grid2:GetUnitOfGUID(guid) then self.active[guid] = nil end
	end
end

function Timed:IsActive(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry ~= nil and (not entry.expires or entry.expires > GetTime())
end

function Timed:GetDuration(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.duration
end

function Timed:GetExpirationTime(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.expires
end

-- Bar / alpha indicators: remaining fraction of the duration (full while there is no expiry).
function Timed:GetPercent(unit)
	local entry = self.active[UnitGUID(unit)]
	if not entry then return 0 end
	if not entry.expires then return 1 end
	local left = (entry.expires - GetTime()) / entry.duration
	return left > 0 and left or 0
end

-- Color indicators: the status color chosen in the options.
function Timed:GetColor()
	local c = self.color
	return c.r, c.g, c.b, c.a
end
