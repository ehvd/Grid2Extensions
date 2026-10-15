-- Grid2Extensions: extra statuses for Grid2.
--
-- "cast": one status per tracked spell. It shows an icon on the caster's Grid2 frame for a few seconds after they
-- successfully cast that spell, for spells that leave no buff on the caster (Challenging Shout...).
-- Statuses are created in the Grid2 options under Statuses > Casts, the same way Buffs are.

local Grid2 = Grid2
if not Grid2 then return end

local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local CATEGORY_ICON = "Interface\\Icons\\Ability_BullRush"
local DEFAULT_DURATION = 6
local WHITE = { r = 1, g = 1, b = 1, a = 1 }

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local C_Timer = C_Timer
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local pairs, tonumber, tostring = pairs, tonumber, tostring
local strtrim, gsub = strtrim, gsub
local table_sort = table.sort
local wipe = wipe

---------------------------------------------------------------------------------------------------------------
-- Spell helpers
---------------------------------------------------------------------------------------------------------------

-- Classic has no spell database API, so spell names are resolved from a lazily built index of the vanilla spell
-- ID range: ids ascending (player abilities have low IDs) and their lowercased names.
local SCAN_MAX_ID = 40000
local indexIds, indexNames

local function BuildIndex()
	if indexIds then return end
	indexIds, indexNames = {}, {}
	for id = 1, SCAN_MAX_ID do
		local name = GetSpellInfo(id)
		if name and name ~= "" then
			indexIds[#indexIds + 1] = id
			indexNames[#indexNames + 1] = strlower(name)
		end
	end
end

-- First spell whose name is exactly `name` (case-insensitive), for names typed without picking a suggestion.
local function FindSpellByName(name)
	BuildIndex()
	name = strlower(name)
	for i = 1, #indexIds do
		if indexNames[i] == name then return indexIds[i] end
	end
end

-- "1161" or "Challenging Shout" -> spell ID, or nil when it is not a known spell.
local function ParseSpell(text)
	text = strtrim(tostring(text or ""))
	if text == "" then return end
	local id = tonumber(text)
	if id then return GetSpellInfo(id) and id or nil end
	return FindSpellByName(text)
end

---------------------------------------------------------------------------------------------------------------
-- Shared combat log dispatcher: one event handler for all cast statuses
---------------------------------------------------------------------------------------------------------------

local enabled = {} -- [status] = true, statuses that currently have indicators
local bySpell = {} -- [spellID] = { [status] = true }
local frame = CreateFrame("Frame")

local function UpdateFrameEvents()
	if next(enabled) then
		frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		frame:RegisterEvent("GROUP_ROSTER_UPDATE")
		frame:RegisterEvent("PLAYER_LOGOUT")
	else
		frame:UnregisterAllEvents()
	end
end

frame:SetScript("OnEvent", function(_, event)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
		if subevent ~= "SPELL_CAST_SUCCESS" or not sourceGUID then return end
		local statuses = bySpell[spellID]
		if not statuses then return end
		local unit = Grid2:GetUnitOfGUID(sourceGUID) -- nil unless the caster is in our party/raid
		if not unit then return end
		for status in pairs(statuses) do status:Trigger(sourceGUID, unit) end
	elseif event == "GROUP_ROSTER_UPDATE" then
		for status in pairs(enabled) do status:Prune() end
	else -- PLAYER_LOGOUT
		for status in pairs(enabled) do wipe(status.active) end
	end
end)

---------------------------------------------------------------------------------------------------------------
-- The "cast" status. dbx = { type = "cast", spellId = id, duration = seconds, texture = optional }
---------------------------------------------------------------------------------------------------------------

local Cast = {}

function Cast:UpdateDB()
	local dbx = self.dbx
	self.spellId = dbx.spellId
	self.duration = dbx.duration or DEFAULT_DURATION
	self.texture = dbx.texture
	self.color = dbx.color1 or WHITE
end

function Cast:OnEnable()
	enabled[self] = true
	local id = self.spellId
	if id then
		bySpell[id] = bySpell[id] or {}
		bySpell[id][self] = true
	end
	UpdateFrameEvents()
end

function Cast:OnDisable()
	enabled[self] = nil
	local statuses = bySpell[self.spellId]
	if statuses then
		statuses[self] = nil
		if not next(statuses) then bySpell[self.spellId] = nil end
	end
	wipe(self.active) -- pending timers find no matching entry and do nothing
	UpdateFrameEvents()
end

-- Active icons by caster GUID. Keyed by GUID, not unit, because unit tokens change when the roster shuffles.
-- Each timer only clears the entry it created, so a recast refreshes the icon instead of being cut short.
function Cast:Trigger(guid, unit)
	local duration = self.duration
	local entry = { expires = GetTime() + duration, duration = duration }
	self.active[guid] = entry
	C_Timer.After(duration, function()
		if self.active[guid] ~= entry then return end
		self.active[guid] = nil
		local current = Grid2:GetUnitOfGUID(guid)
		if current then self:UpdateIndicators(current) end
	end)
	self:UpdateIndicators(unit)
end

-- Drop entries of players who left the group; their frames are gone, so no indicator update is needed.
function Cast:Prune()
	for guid in pairs(self.active) do
		if not Grid2:GetUnitOfGUID(guid) then self.active[guid] = nil end
	end
end

function Cast:IsActive(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry ~= nil and entry.expires > GetTime()
end

-- Icon shown for this status: the configured texture, else the spell's own icon.
function Cast:GetTexture()
	if self.texture then return self.texture end
	local _, _, icon = GetSpellInfo(self.spellId or 0)
	return icon or FALLBACK_TEXTURE
end

function Cast:GetIcon(unit)
	return self.active[UnitGUID(unit)] and self:GetTexture()
end

function Cast:GetDuration(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.duration
end

function Cast:GetExpirationTime(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.expires
end

-- Color indicators (square, border, bar color, text color...): the status color chosen in the options.
function Cast:GetColor()
	local c = self.color
	return c.r, c.g, c.b, c.a
end

-- Text indicators: the spell name (the text indicator can also show the remaining time by itself).
function Cast:GetText()
	return (GetSpellInfo(self.spellId or 0))
end

-- Bar / alpha indicators: remaining fraction of the duration.
function Cast:GetPercent(unit)
	local entry = self.active[UnitGUID(unit)]
	if not entry then return 0 end
	local left = (entry.expires - GetTime()) / entry.duration
	return left > 0 and left or 0
end

local function CreateCast(baseKey, dbx)
	local status = Grid2.statusPrototype:new(baseKey, false) -- no AceEvent: events go through the shared frame
	status:Inject(Cast)
	status.active = {}
	if not dbx.spellId and dbx.spellIds then dbx.spellId = dbx.spellIds[1] end -- pre-release format
	dbx.spellIds = nil
	Grid2:RegisterStatus(status, { "color", "icon", "text", "percent" }, baseKey, dbx)
	return status
end

Grid2.setupFunc["cast"] = CreateCast -- luacheck: ignore 122

-- Creates, stores and registers a new cast status. Returns the status, or nil if the spell is unknown.
local function AddCastStatus(spellId, duration, texture)
	local spellName = spellId and GetSpellInfo(spellId)
	if not spellName then return end
	local baseKey = gsub(spellName, "[ %.\"]", "")
	local statuses = Grid2.db.profile.statuses
	if statuses[baseKey] then baseKey = baseKey .. "-" .. spellId end
	if statuses[baseKey] then return end
	local dbx = { type = "cast", spellId = spellId, duration = duration, texture = texture, color1 = { r = 1, g = 1, b = 1, a = 1 } }
	statuses[baseKey] = dbx
	return CreateCast(baseKey, dbx), baseKey
end

---------------------------------------------------------------------------------------------------------------
-- Migration of the pre-release "cast-tracker" status (one status holding a list of spells)
---------------------------------------------------------------------------------------------------------------

Grid2.setupFunc["cast-tracker"] = function(baseKey, dbx) -- luacheck: ignore 122
	-- Grid2 is iterating the statuses table right now: do the conversion one frame later.
	C_Timer.After(0, function()
		local statuses = Grid2.db and Grid2.db.profile.statuses
		if not statuses or statuses[baseKey] ~= dbx then return end
		local ids = {}
		for id in pairs(dbx.spells or {}) do ids[#ids + 1] = id end
		table_sort(ids)
		for _, id in ipairs(ids) do
			local cfg = dbx.spells[id]
			AddCastStatus(id, cfg.duration, cfg.texture)
		end
		statuses[baseKey] = nil
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Grid2Options (load-on-demand): "Casts" category with a "New Cast" page, like Buffs
---------------------------------------------------------------------------------------------------------------

-- Suggestions while typing a spell name (AceGUI-3.0-Search-EditBox predictor, the same widget Buffs use).
local Predictor = {}

local function SpellLabel(id, name, icon)
	local rank = GetSpellSubtext and GetSpellSubtext(id)
	return format("|T%s:0|t%s%s, |cff808080%d|r", icon or "", name, rank and rank ~= "" and " (" .. rank .. ")" or "", id)
end

function Predictor:GetValues(text, values, max)
	text = strtrim(text or "")
	if text == "" then return end
	local id = strmatch(text, "^%d+$") and tonumber(text)
	if id then
		local name, _, icon = GetSpellInfo(id)
		if name then values[id] = SpellLabel(id, name, icon) end
		return
	end
	if #text < 2 then return end
	BuildIndex()
	text = strlower(text)
	local len = #text
	for i = 1, #indexIds do
		if strsub(indexNames[i], 1, len) == text then
			local spellID = indexIds[i]
			local name, _, icon = GetSpellInfo(spellID)
			values[spellID] = SpellLabel(spellID, name, icon)
			max = max - 1
			if max == 0 then return end
		end
	end
end

-- Called with the typed text and, when the user picks a suggestion, its key (the spell ID). The first return value
-- is what the widget hands to AceConfig, the second is the text shown in the box.
function Predictor:GetValue(text, key)
	if key then return tostring(key), tostring(key) end
	return text, text
end

function Predictor:GetHyperlink(key)
	return "spell:" .. key
end

local function MakeStatusOptions(self, status, options)
	local dbx = status.dbx
	options.spell = {
		type = "description", order = 10, fontSize = "medium",
		name = function()
			local name, _, icon = GetSpellInfo(dbx.spellId or 0)
			return format("|T%s:20|t %s, |cff808080%d|r", icon or "", name or "Unknown spell", dbx.spellId or 0)
		end,
	}
	if not dbx.color1 then dbx.color1 = { r = 1, g = 1, b = 1, a = 1 } end
	self:MakeStatusColorOptions(status, options)
	options.duration = {
		type = "range", order = 20, name = "Duration (s)", min = 0.5, max = 60, step = 0.5,
		desc = "How long the icon stays visible after the cast.",
		get = function() return dbx.duration or DEFAULT_DURATION end,
		set = function(_, v)
			dbx.duration = v
			status:Refresh()
		end,
	}
	options.texture = {
		type = "input", order = 30, width = "double", name = "Texture (optional)",
		desc = "Icon path or file ID. Leave empty to use the spell's own icon.",
		get = function() return dbx.texture and tostring(dbx.texture) or "" end,
		set = function(_, v)
			v = strtrim(v)
			dbx.texture = v ~= "" and (tonumber(v) or v) or nil
			status:Refresh()
			self:MakeStatusOptions(status) -- the icon in the tree follows the texture
		end,
	}
end

local function MakeCategoryOptions(Options)
	local newSpell = ""
	return {
		newCastSpell = {
			type = "input", dialogControl = "EditBoxGrid2Casts", order = 5, width = "full", name = "Spell ID or name",
			usage = "Start typing a spell name to get suggestions, or enter a spell ID.",
			get = function() return newSpell end,
			set = function(_, v) newSpell = tostring(v) end,
			validate = function(_, v)
				if strtrim(tostring(v)) == "" or ParseSpell(v) then return true end
				return "Unknown spell: " .. tostring(v)
			end,
		},
		newCastSpacer = { type = "header", order = 5.4, name = "" },
		newCast = {
			type = "execute", order = 5.5, name = "Create", desc = "Create a new Cast status.",
			disabled = function() return not ParseSpell(newSpell) end,
			func = function()
				local status = AddCastStatus(ParseSpell(newSpell), DEFAULT_DURATION)
				if status then
					newSpell = ""
					Options:MakeStatusOptions(status)
					Options:SelectGroup("statuses", Options:GetStatusCategory(status), status.name)
				end
			end,
		},
	}
end

local function RegisterOptions()
	local Options = Grid2Options
	LibStub("AceGUI-3.0-Search-EditBox"):Register("Grid2Casts", Predictor)
	Options:RegisterStatusCategory("cast", {
		name = "Casts", title = "New Cast", order = 15, icon = CATEGORY_ICON,
		desc = "Spell casts that leave no buff on the caster",
		options = MakeCategoryOptions(Options),
	})
	Options:RegisterStatusOptions("cast", "cast", MakeStatusOptions, {
		title = "Cast", titleIcon = CATEGORY_ICON, isDeletable = true, groupOrder = 50,
		titleDesc = "Shows an icon on a unit for a few seconds after it casts the spell.",
	})
	-- Buffs get their tree icon from the spell; do the same for casts.
	local GetStatusInfo = Options.GetStatusInfo
	function Options:GetStatusInfo(status, params)
		local catGroup, name, desc, icon, coords, deletable, p = GetStatusInfo(self, status, params)
		if catGroup and status.dbx.type == "cast" and status.GetTexture then icon = status:GetTexture() end
		return catGroup, name, desc, icon, coords, deletable, p
	end
end

if Grid2Options then
	RegisterOptions()
else
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, _, addon)
		if addon == "Grid2Options" and Grid2Options then
			self:UnregisterEvent("ADDON_LOADED")
			RegisterOptions()
		end
	end)
end
