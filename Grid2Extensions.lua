-- Grid2Extensions: extra statuses for Grid2.
--
-- "cast-tracker": shows an icon on the caster's Grid2 frame for a few seconds after they successfully cast a
-- tracked spell that leaves no buff on the caster (e.g. Challenging Shout). Driven by the combat log.

local Grid2 = Grid2
if not Grid2 then return end

---------------------------------------------------------------------------------------------------------------
-- Configuration: add spells here. The key is the spell ID (Classic has one ID per rank: list every rank).
--   duration = seconds the icon stays visible
--   texture  = optional; defaults to the spell's own icon (falls back to the question mark)
---------------------------------------------------------------------------------------------------------------
local TRACKED_SPELLS = {
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

local function GetTexture(spellID)
	local cfg = TRACKED_SPELLS[spellID]
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
	local cfg = TRACKED_SPELLS[spellID]
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

Grid2.setupFunc["cast-tracker"] = function(baseKey, dbx)
	Grid2:RegisterStatus(status, { "icon" }, baseKey, dbx)
	return status
end

Grid2:DbSetStatusDefaultValue("cast-tracker", { type = "cast-tracker" })

-- Grid2Options is load-on-demand: register the options entry (category "Combat") once it is available.
local function RegisterOptions()
	Grid2Options:RegisterStatusOptions("cast-tracker", "combat", nil, {
		title = "Cast Tracker",
		titleDesc = "Shows an icon on a unit after it casts a tracked spell (see TRACKED_SPELLS in Grid2Extensions.lua).",
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
