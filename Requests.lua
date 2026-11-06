-- "request": a status that is switched on for a group member by a whisper or by another addon (WeakAuras).
--
--  * Whisper: if the status has a pattern and a whisper to the player matches it, the status is shown on the
--    sender's Grid2 frame for the configured duration ("Bop me pls!!" -> a Blessing of Protection request).
--  * API: Grid2Extensions.Trigger(statusName, who [, seconds]) and Grid2Extensions.Clear(statusName [, who]) let a
--    WeakAura (or any code) drive the status, e.g. from the aura's On Show / On Hide custom actions.
--
-- Statuses are created in the Grid2 options under Statuses > Requests, the same way Buffs are.

local _, ns = ...
local Grid2 = Grid2
if not Grid2 then return end

local DEFAULT_DURATION = 10
local DEFAULT_TEXTURE = "Interface\\Icons\\INV_Misc_Note_01"
local CATEGORY_ICON = "Interface\\Icons\\Spell_Holy_SealOfProtection"
local WHITE = { r = 1, g = 1, b = 1, a = 1 }

local UnitGUID = UnitGUID
local pairs, pcall, type, tostring, tonumber = pairs, pcall, type, tostring, tonumber
local strfind, strlower, strtrim, gsub, format = strfind, strlower, strtrim, gsub, format

---------------------------------------------------------------------------------------------------------------
-- The "request" status. dbx = { type = "request", pattern = text, usePattern = bool, duration = seconds,
-- texture = optional, color1 = color }. duration 0 = stays until Clear() is called (WeakAuras).
---------------------------------------------------------------------------------------------------------------

local Request = {}
local enabled = {} -- [status] = true, request statuses that currently have indicators
local frame = CreateFrame("Frame")

local function UpdateFrameEvents()
	local wanted
	for status in pairs(enabled) do
		if status.pattern then wanted = true break end
	end
	if wanted then frame:RegisterEvent("CHAT_MSG_WHISPER") else frame:UnregisterAllEvents() end
end

-- Plain mode: case-insensitive substring. Pattern mode: Lua pattern against the lowercased message.
function Request:Matches(text)
	local pattern = self.pattern
	if not pattern then return false end
	text = strlower(text)
	if self.usePattern then
		local ok, found = pcall(strfind, text, pattern)
		return ok and found ~= nil
	end
	return strfind(text, strlower(pattern), 1, true) ~= nil
end

-- CHAT_MSG_WHISPER payload: text, playerName, ..., guid is the 12th argument.
frame:SetScript("OnEvent", function(_, _, text, _, _, _, _, _, _, _, _, _, _, guid)
	if not text or not guid then return end
	local unit = Grid2:GetUnitOfGUID(guid) -- nil unless the sender is in our party/raid
	if not unit then return end
	for status in pairs(enabled) do
		if status:Matches(text) then status:Trigger(guid, unit, status.duration) end
	end
end)

function Request:UpdateDB()
	local dbx = self.dbx
	local pattern = strtrim(dbx.pattern or "")
	self.pattern = pattern ~= "" and pattern or nil
	self.usePattern = dbx.usePattern
	self.duration = dbx.duration or DEFAULT_DURATION
	self.texture = dbx.texture
	self.color = dbx.color1 or WHITE
	if enabled[self] then UpdateFrameEvents() end
end

function Request:OnEnable()
	enabled[self] = true
	self:Track()
	UpdateFrameEvents()
end

function Request:OnDisable()
	enabled[self] = nil
	self:Untrack()
	UpdateFrameEvents()
end

-- Icon shown for this status: the configured texture, else a generic note icon.
function Request:GetTexture()
	return self.texture or DEFAULT_TEXTURE
end

function Request:GetIcon(unit)
	return self.active[UnitGUID(unit)] and self:GetTexture()
end

-- Text indicators: the status name (a text indicator can also show the remaining time by itself).
function Request:GetText()
	return self.name
end

local function CreateRequest(baseKey, dbx)
	local status = Grid2.statusPrototype:new(baseKey, false) -- no AceEvent: events go through the shared frame
	status:Inject(ns.Timed)
	status:Inject(Request)
	status.active = {}
	Grid2:RegisterStatus(status, { "color", "icon", "text", "percent" }, baseKey, dbx)
	return status
end

Grid2.setupFunc["request"] = CreateRequest -- luacheck: ignore 122

local function KeyFromName(name)
	return gsub(strtrim(name or ""), "[ %.\"]", "")
end

-- Creates, stores and registers a new request status. Returns the status, or nil if the name is empty or taken.
local function AddRequestStatus(name, pattern)
	local baseKey = KeyFromName(name)
	local statuses = Grid2.db.profile.statuses
	if baseKey == "" or statuses[baseKey] then return end
	pattern = strtrim(pattern or "")
	local dbx = {
		type = "request", pattern = pattern ~= "" and pattern or nil, duration = DEFAULT_DURATION,
		color1 = { r = 1, g = 1, b = 1, a = 1 },
	}
	statuses[baseKey] = dbx
	return CreateRequest(baseKey, dbx), baseKey
end

---------------------------------------------------------------------------------------------------------------
-- Public API (for WeakAuras custom actions and other addons)
---------------------------------------------------------------------------------------------------------------

Grid2Extensions = Grid2Extensions or {}

local function FindRequest(name)
	local status = Grid2.statuses[KeyFromName(name)]
	return status and status.dbx.type == "request" and status or nil
end

-- unit token ("raid3"), player name ("Name" / "Name-Realm", must be in the group) or GUID -> guid, unit
local function Resolve(who)
	if type(who) ~= "string" then return end
	local guid = strfind(who, "^Player%-") and who or UnitGUID(who)
	if not guid then return end
	return guid, Grid2:GetUnitOfGUID(guid)
end

-- Grid2Extensions.Trigger("Bop", "Playername" [, seconds]): show the request status on that player's frame.
-- seconds omitted: the status' configured duration. seconds = 0: stays until Grid2Extensions.Clear is called.
-- Returns true when the status was switched on (it must exist, have indicators linked and the player must be in
-- the group).
function Grid2Extensions.Trigger(name, who, seconds)
	local status = FindRequest(name)
	if not status or not enabled[status] then return false end
	local guid, unit = Resolve(who)
	if not guid or not unit then return false end
	status:Trigger(guid, unit, seconds or status.duration)
	return true
end

-- Grid2Extensions.Clear("Bop" [, "Playername"]): switch the status off for one player, or for everybody.
function Grid2Extensions.Clear(name, who)
	local status = FindRequest(name)
	if not status then return false end
	if who == nil then
		for guid in pairs(status.active) do status:Clear(guid) end
		return true
	end
	local guid = Resolve(who)
	if not guid then return false end
	status:Clear(guid)
	return true
end

---------------------------------------------------------------------------------------------------------------
-- Grid2Options (load-on-demand): "Requests" category with a "New Request" page, like Buffs
---------------------------------------------------------------------------------------------------------------

local function MakeStatusOptions(self, status, options)
	local dbx = status.dbx
	if not dbx.color1 then dbx.color1 = { r = 1, g = 1, b = 1, a = 1 } end
	self:MakeStatusColorOptions(status, options)
	options.pattern = {
		type = "input", order = 20, width = "double", name = "Whisper text",
		desc = "Show this status on the sender when a whisper to you contains this text (not case sensitive). "
			.. "Leave empty to only use it from WeakAuras.",
		get = function() return dbx.pattern or "" end,
		set = function(_, v)
			v = strtrim(v)
			dbx.pattern = v ~= "" and v or nil
			status:Refresh()
		end,
	}
	options.usePattern = {
		type = "toggle", order = 21, name = "Lua pattern",
		desc = "Treat the whisper text as a Lua pattern, matched against the lowercased message (for example ^bop).",
		get = function() return dbx.usePattern end,
		set = function(_, v)
			dbx.usePattern = v or nil
			status:Refresh()
		end,
	}
	options.duration = {
		type = "range", order = 30, name = "Duration (s)", min = 0, max = 60, step = 0.5,
		desc = "How long the status stays after a whisper. 0 keeps it until a WeakAura clears it.",
		get = function() return dbx.duration or DEFAULT_DURATION end,
		set = function(_, v)
			dbx.duration = v
			status:Refresh()
		end,
	}
	options.texture = {
		type = "input", order = 40, width = "double", name = "Texture (optional)",
		desc = "Icon path or file ID for icon indicators.",
		get = function() return dbx.texture and tostring(dbx.texture) or "" end,
		set = function(_, v)
			v = strtrim(v)
			dbx.texture = v ~= "" and (tonumber(v) or v) or nil
			status:Refresh()
			self:MakeStatusOptions(status) -- the icon in the tree follows the texture
		end,
	}
	options.api = {
		type = "description", order = 50, fontSize = "medium",
		name = function()
			return format("\n|cff808080WeakAuras:|r Grid2Extensions.Trigger(\"%s\", unit [, seconds])\n"
				.. "|cff808080Clear:|r Grid2Extensions.Clear(\"%s\" [, unit])", status.name, status.name)
		end,
	}
end

local function MakeCategoryOptions(Options)
	local newName, newPattern = "", ""
	return {
		newRequestName = {
			type = "input", order = 5, width = "full", name = "Name",
			desc = "Name of the status. WeakAuras refer to the status by this name.",
			get = function() return newName end,
			set = function(_, v) newName = v end,
			validate = function(_, v)
				local key = KeyFromName(v)
				if key ~= "" and Grid2.statuses[key] then return "A status with this name already exists." end
				return true
			end,
		},
		newRequestPattern = {
			type = "input", order = 5.1, width = "full", name = "Whisper text (optional)",
			desc = "Show the status on the sender when a whisper to you contains this text (not case sensitive).",
			get = function() return newPattern end,
			set = function(_, v) newPattern = v end,
		},
		newRequestSpacer = { type = "header", order = 5.4, name = "" },
		newRequest = {
			type = "execute", order = 5.5, name = "Create", desc = "Create a new Request status.",
			disabled = function()
				local key = KeyFromName(newName)
				return key == "" or Grid2.statuses[key] ~= nil
			end,
			func = function()
				local status = AddRequestStatus(newName, newPattern)
				if status then
					newName, newPattern = "", ""
					Options:MakeStatusOptions(status)
					Options:SelectGroup("statuses", Options:GetStatusCategory(status), status.name)
				end
			end,
		},
	}
end

ns.OnGrid2Options(function()
	local Options = Grid2Options
	Options:RegisterStatusCategory("request", {
		name = "Requests", title = "New Request", order = 16, icon = CATEGORY_ICON,
		desc = "Statuses switched on by a whisper or by WeakAuras",
		options = MakeCategoryOptions(Options),
	})
	Options:RegisterStatusOptions("request", "request", MakeStatusOptions, {
		title = "Request", titleIcon = CATEGORY_ICON, isDeletable = true, groupOrder = 50,
		titleDesc = "Shown on a group member after a matching whisper, or while a WeakAura asks for it.",
	})
end)
