-- Grid2Extensions: extra statuses for Grid2.
--
-- "cast-tracker": shows an icon on the caster's Grid2 frame for a few seconds after they successfully cast a
-- tracked spell that leaves no buff on the caster (e.g. Challenging Shout). Driven by the combat log.

local Grid2 = Grid2
if not Grid2 then return end

---------------------------------------------------------------------------------------------------------------
-- Default spells, seeded into the saved settings once. After that, edit the list in game: Grid2 options >
-- Statuses > Combat > cast-tracker. The key is the spell ID (Classic has one ID per rank: list every rank).
--   duration = seconds the icon stays visible
--   texture  = optional; defaults to the spell's own icon (falls back to the question mark)
---------------------------------------------------------------------------------------------------------------
local DEFAULT_SPELLS = {
	[1161] = { duration = 6, texture = "Interface\\Icons\\Ability_BullRush" }, -- Challenging Shout
}
local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local C_Timer = C_Timer
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local pairs = pairs
local wipe = wipe

local status = Grid2.statusPrototype:new("cast-tracker")

-- Active icons by caster GUID: { expires = <GetTime>, spellID = <id> }. Keyed by GUID, not unit, because unit
-- tokens change when the roster shuffles. Each timer callback only clears the entry it created.
local active = {}

local function CopySpells(src)
	local copy = {}
	for id, cfg in pairs(src) do copy[id] = { duration = cfg.duration, texture = cfg.texture } end
	return copy
end

-- The tracked spells live in the status settings (dbx.spells, edited in the Grid2 options). They are seeded from
-- DEFAULT_SPELLS once; after that the saved list is authoritative, so removing a default spell sticks.
function status:UpdateDB()
	local dbx = self.dbx
	if not dbx.spells then dbx.spells = CopySpells(DEFAULT_SPELLS) end
	self.spells = dbx.spells
end

local function GetTexture(spellID)
	local cfg = status.spells[spellID]
	if cfg and cfg.texture then return cfg.texture end
	local _, _, icon = GetSpellInfo(spellID)
	return icon or FALLBACK_TEXTURE
end

local function Expire(guid, entry)
	if active[guid] ~= entry then return end -- refreshed by a newer cast, or already cleared
	active[guid] = nil
	local unit = Grid2:GetUnitOfGUID(guid)
	if unit then status:UpdateIndicators(unit) end
end

function status:COMBAT_LOG_EVENT_UNFILTERED()
	local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
	if subevent ~= "SPELL_CAST_SUCCESS" then return end
	local cfg = self.spells[spellID]
	if not cfg or not sourceGUID then return end
	local unit = Grid2:GetUnitOfGUID(sourceGUID) -- nil unless the caster is in our party/raid
	if not unit then return end

	local entry = { expires = GetTime() + cfg.duration, spellID = spellID, duration = cfg.duration }
	active[sourceGUID] = entry
	C_Timer.After(cfg.duration, function() Expire(sourceGUID, entry) end)
	self:UpdateIndicators(unit)
end

-- Drop entries of players who left the group; their frames are gone, so no indicator update is needed.
function status:GROUP_ROSTER_UPDATE()
	for guid in pairs(active) do
		if not Grid2:GetUnitOfGUID(guid) then active[guid] = nil end
	end
end

function status:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("PLAYER_LOGOUT", "OnDisable")
end

function status:OnDisable()
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("PLAYER_LOGOUT")
	wipe(active) -- pending timers find no matching entry and do nothing
end

function status:IsActive(unit)
	local entry = active[UnitGUID(unit)]
	return entry ~= nil and entry.expires > GetTime()
end

function status:GetIcon(unit)
	local entry = active[UnitGUID(unit)]
	return entry and GetTexture(entry.spellID)
end

function status:GetDuration(unit)
	local entry = active[UnitGUID(unit)]
	return entry and entry.duration
end

function status:GetExpirationTime(unit)
	local entry = active[UnitGUID(unit)]
	return entry and entry.expires
end

function status:GetColor()
	return 1, 1, 1, 1
end

Grid2.setupFunc["cast-tracker"] = function(baseKey, dbx) -- luacheck: ignore 122
	Grid2:RegisterStatus(status, { "icon" }, baseKey, dbx)
	return status
end

Grid2:DbSetStatusDefaultValue("cast-tracker", { type = "cast-tracker" })

-- Grid2Options is load-on-demand: register the options entry (category "Combat") once it is available.
local function BuildSpellOptions(args)
	wipe(args)
	local ids = {}
	for id in pairs(status.spells) do ids[#ids + 1] = id end
	table.sort(ids)
	for i, id in ipairs(ids) do
		local cfg = status.spells[id]
		args["spell" .. id] = {
			type = "group", inline = true, order = 20 + i,
			name = function()
				return format("|T%s:16|t %s (%d)", tostring(GetTexture(id)), GetSpellInfo(id) or "?", id)
			end,
			args = {
				duration = {
					type = "range", order = 1, name = "Duration (s)", min = 0.5, max = 60, step = 0.5,
					get = function() return cfg.duration end,
					set = function(_, v) cfg.duration = v end,
				},
				texture = {
					type = "input", order = 2, width = "double", name = "Texture (optional)",
					desc = "Icon path or file ID. Leave empty to use the spell's own icon.",
					get = function() return cfg.texture and tostring(cfg.texture) or "" end,
					set = function(_, v)
						v = strtrim(v)
						cfg.texture = v ~= "" and (tonumber(v) or v) or nil
					end,
				},
				remove = {
					type = "execute", order = 3, name = "Remove",
					func = function()
						status.spells[id] = nil
						BuildSpellOptions(args)
						Grid2Options:NotifyChange()
					end,
				},
			},
		}
	end
end

local function MakeOptions(self, _, options)
	local args = {}
	options.add = {
		type = "input", order = 10, name = "Add spell ID",
		desc = "Spell ID to track. Classic has one ID per rank, so add every rank you need.",
		get = function() return "" end,
		validate = function(_, v)
			local id = tonumber(v)
			if not id or not GetSpellInfo(id) then return "Unknown spell ID" end
			return true
		end,
		set = function(_, v)
			local id = tonumber(v)
			status.spells[id] = status.spells[id] or { duration = 6 }
			BuildSpellOptions(args)
			Grid2Options:NotifyChange()
		end,
	}
	options.reset = {
		type = "execute", order = 11, name = "Reset to defaults",
		confirm = true, confirmText = "Replace the tracked spell list with the defaults?",
		func = function()
			status.dbx.spells = nil
			status:UpdateDB()
			BuildSpellOptions(args)
			Grid2Options:NotifyChange()
		end,
	}
	options.spells = { type = "group", inline = true, order = 20, name = "Tracked spells", args = args }
	BuildSpellOptions(args)
end

local function RegisterOptions()
	Grid2Options:RegisterStatusOptions("cast-tracker", "combat", MakeOptions, {
		title = "Cast Tracker",
		titleDesc = "Shows an icon on a unit for a few seconds after it casts a tracked spell.",
		titleIcon = "Interface\\Icons\\Ability_BullRush",
	})
end

if Grid2Options then
	RegisterOptions()
else
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(self, _, addon)
		if addon == "Grid2Options" and Grid2Options then
			self:UnregisterEvent("ADDON_LOADED")
			RegisterOptions()
		end
	end)
end
