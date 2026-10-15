-- Grid2Extensions: extra statuses for Grid2.
--
-- "cast": one status per tracked cast. It shows an icon on the caster's Grid2 frame for a few seconds after they
-- successfully cast one of the status' spells, for spells that leave no buff on the caster (Challenging Shout...).
-- Statuses are created in the Grid2 options under Statuses > Casts, the same way Buffs are.

local Grid2 = Grid2
if not Grid2 then return end

local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local CATEGORY_ICON = "Interface\\Icons\\Ability_BullRush"
local DEFAULT_DURATION = 6

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local C_Timer = C_Timer
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local strtrim, gsub = strtrim, gsub
local table_concat, table_sort = table.concat, table.sort
local wipe = wipe

---------------------------------------------------------------------------------------------------------------
-- Spell ID helpers
---------------------------------------------------------------------------------------------------------------

-- "1161, 694" or "Challenging Shout" -> { ids }. Returns nil, badToken when something is not a known spell.
local function ParseSpellIds(text)
	local ids = {}
	for token in (text or ""):gmatch("[^,;]+") do
		token = strtrim(token)
		if token ~= "" then
			local id = tonumber(token)
			if id then
				if not GetSpellInfo(id) then return nil, token end
			else
				id = select(7, GetSpellInfo(token))
				if not id then return nil, token end
			end
			ids[#ids + 1] = id
		end
	end
	if #ids == 0 then return nil, text end
	return ids
end

local function JoinSpellIds(ids)
	local t = {}
	for i, id in ipairs(ids or {}) do t[i] = tostring(id) end
	return table_concat(t, ", ")
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
		for status in pairs(statuses) do status:Trigger(sourceGUID, unit, spellID) end
	elseif event == "GROUP_ROSTER_UPDATE" then
		for status in pairs(enabled) do status:Prune() end
	else -- PLAYER_LOGOUT
		for status in pairs(enabled) do wipe(status.active) end
	end
end)

---------------------------------------------------------------------------------------------------------------
-- The "cast" status. dbx = { type = "cast", spellIds = { ... }, duration = seconds, texture = optional }
---------------------------------------------------------------------------------------------------------------

local Cast = {}

function Cast:UpdateDB()
	local dbx = self.dbx
	self.spellIds = dbx.spellIds or {}
	self.duration = dbx.duration or DEFAULT_DURATION
	self.texture = dbx.texture
end

function Cast:OnEnable()
	enabled[self] = true
	for _, id in ipairs(self.spellIds) do
		bySpell[id] = bySpell[id] or {}
		bySpell[id][self] = true
	end
	UpdateFrameEvents()
end

function Cast:OnDisable()
	enabled[self] = nil
	for _, id in ipairs(self.spellIds) do
		local statuses = bySpell[id]
		if statuses then
			statuses[self] = nil
			if not next(statuses) then bySpell[id] = nil end
		end
	end
	wipe(self.active) -- pending timers find no matching entry and do nothing
	UpdateFrameEvents()
end

-- Active icons by caster GUID. Keyed by GUID, not unit, because unit tokens change when the roster shuffles.
-- Each timer only clears the entry it created, so a recast refreshes the icon instead of being cut short.
function Cast:Trigger(guid, unit, spellID)
	local duration = self.duration
	local entry = { expires = GetTime() + duration, duration = duration, spellID = spellID }
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

-- Icon shown for this status: the configured texture, else the icon of the first spell.
function Cast:GetTexture(spellID)
	if self.texture then return self.texture end
	local _, _, icon = GetSpellInfo(spellID or self.spellIds[1] or 0)
	return icon or FALLBACK_TEXTURE
end

function Cast:GetIcon(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and self:GetTexture(entry.spellID)
end

function Cast:GetDuration(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.duration
end

function Cast:GetExpirationTime(unit)
	local entry = self.active[UnitGUID(unit)]
	return entry and entry.expires
end

function Cast:GetColor()
	return 1, 1, 1, 1
end

local function CreateCast(baseKey, dbx)
	local status = Grid2.statusPrototype:new(baseKey, false) -- no AceEvent: events go through the shared frame
	status:Inject(Cast)
	status.active = {}
	Grid2:RegisterStatus(status, { "icon" }, baseKey, dbx)
	return status
end

Grid2.setupFunc["cast"] = CreateCast -- luacheck: ignore 122

-- Creates, stores and registers a new cast status. Returns the status, or nil if the spell is unknown.
local function AddCastStatus(spellIds, duration, texture)
	local spellName = GetSpellInfo(spellIds[1])
	if not spellName then return end
	local baseKey = "cast-" .. gsub(spellName, "[ %.\"]", "")
	local statuses = Grid2.db.profile.statuses
	if statuses[baseKey] then baseKey = baseKey .. "-" .. spellIds[1] end
	if statuses[baseKey] then return end
	local dbx = { type = "cast", spellIds = spellIds, duration = duration, texture = texture }
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
			AddCastStatus({ id }, cfg.duration, cfg.texture)
		end
		statuses[baseKey] = nil
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Grid2Options (load-on-demand): "Casts" category with a "New Cast" page, like Buffs
---------------------------------------------------------------------------------------------------------------

local function MakeStatusOptions(self, status, options)
	local dbx = status.dbx
	options.spellIds = {
		type = "input", order = 10, width = "full", name = "Spell IDs",
		desc = "Spell IDs or names, separated by commas. Classic has one ID per rank, so list every rank.",
		get = function() return JoinSpellIds(dbx.spellIds) end,
		validate = function(_, v)
			local ids, bad = ParseSpellIds(v)
			if not ids then return "Unknown spell: " .. tostring(bad) end
			return true
		end,
		set = function(_, v)
			dbx.spellIds = ParseSpellIds(v)
			status:Refresh()
			self:MakeStatusOptions(status) -- the icon in the tree depends on the first spell
		end,
	}
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
			self:MakeStatusOptions(status)
		end,
	}
end

local function MakeCategoryOptions(Options)
	local newSpells, newDuration = "", DEFAULT_DURATION
	return {
		newCastSpells = {
			type = "input", order = 5, width = "full", name = "Spell IDs or names",
			desc = "Spell IDs or names, separated by commas. Classic has one ID per rank, so list every rank.",
			get = function() return newSpells end,
			set = function(_, v) newSpells = v end,
			validate = function(_, v)
				if strtrim(v) == "" then return true end
				local ids, bad = ParseSpellIds(v)
				if not ids then return "Unknown spell: " .. tostring(bad) end
				return true
			end,
		},
		newCastDuration = {
			type = "range", order = 5.1, name = "Duration (s)", min = 0.5, max = 60, step = 0.5,
			desc = "How long the icon stays visible after the cast.",
			get = function() return newDuration end,
			set = function(_, v) newDuration = v end,
		},
		newCastSpacer = { type = "header", order = 5.4, name = "" },
		newCast = {
			type = "execute", order = 5.5, name = "Create", desc = "Create a new Cast status.",
			disabled = function() return not ParseSpellIds(newSpells) end,
			func = function()
				local status = AddCastStatus(ParseSpellIds(newSpells), newDuration)
				if status then
					newSpells = ""
					Options:MakeStatusOptions(status)
					Options:SelectGroup("statuses", Options:GetStatusCategory(status), status.name)
				end
			end,
		},
	}
end

local function RegisterOptions()
	local Options = Grid2Options
	Options:RegisterStatusCategory("cast", {
		name = "Casts", title = "New Cast", order = 15, icon = CATEGORY_ICON,
		desc = "Spell casts that leave no buff on the caster",
		options = MakeCategoryOptions(Options),
	})
	Options:RegisterStatusOptions("cast", "cast", MakeStatusOptions, {
		title = "Cast", titleIcon = CATEGORY_ICON, isDeletable = true, groupOrder = 50,
		titleDesc = "Shows an icon on a unit for a few seconds after it casts one of the spells.",
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
