-- "summon-request": active for every group member who is on the RaidSummon addon's summon list.
-- RaidSummon rebuilds RaidSummon.browseDB (one row per requester, with the unit token and the position in the
-- queue) inside RaidSummon:UpdateList(), which it calls after every add, remove, sync and roster change. We
-- post-hook that function and mirror the result, so no RaidSummon files are modified.

local _, ns = ...
local Grid2 = Grid2
if not Grid2 then return end

local GetSpellInfo = GetSpellInfo
local UnitGUID = UnitGUID
local pairs, ipairs, tostring = pairs, ipairs, tostring
local wipe = wipe

local RITUAL_OF_SUMMONING = 698
local FALLBACK_ICON = "Interface\\Icons\\Spell_Shadow_Twilight"
local DEFAULT_COLOR = { r = 1, g = 0.6, b = 0, a = 1 }

local status = Grid2.statusPrototype:new("summon-request", false)

local requests = {} -- [guid] = position in the RaidSummon queue
local running, hooked = false, false

local function UpdateGuid(guid)
	local unit = Grid2:GetUnitOfGUID(guid)
	if unit then status:UpdateIndicators(unit) end
end

-- Rebuild `requests` from RaidSummon's list and refresh the frames that changed.
local function Refresh()
	if not running then return end
	local old, new = requests, {}
	local rows = RaidSummon and RaidSummon.browseDB
	if rows then
		for i, row in ipairs(rows) do
			local guid = row.rUnit and UnitGUID(row.rUnit)
			if guid then new[guid] = row.rOrder or i end
		end
	end
	requests = new
	for guid, pos in pairs(old) do
		if new[guid] ~= pos then UpdateGuid(guid) end
	end
	for guid, pos in pairs(new) do
		if old[guid] ~= pos then UpdateGuid(guid) end
	end
end

function status:UpdateDB()
	self.color = self.dbx.color1 or DEFAULT_COLOR
end

function status:OnEnable()
	running = true
	if not hooked and RaidSummon and RaidSummon.UpdateList then
		hooksecurefunc(RaidSummon, "UpdateList", Refresh)
		hooked = true
	end
	Refresh()
end

function status:OnDisable()
	running = false
	wipe(requests)
end

function status:IsActive(unit)
	return requests[UnitGUID(unit)] ~= nil
end

function status:GetIcon()
	local _, _, icon = GetSpellInfo(RITUAL_OF_SUMMONING)
	return icon or FALLBACK_ICON
end

-- Position in the summon queue.
function status:GetText(unit)
	local pos = requests[UnitGUID(unit)]
	return pos and tostring(pos)
end

function status:GetColor()
	local c = self.color
	return c.r, c.g, c.b, c.a
end

Grid2.setupFunc["summon-request"] = function(baseKey, dbx) -- luacheck: ignore 122
	Grid2:RegisterStatus(status, { "color", "icon", "text" }, baseKey, dbx)
	return status
end

Grid2:DbSetStatusDefaultValue("summon-request", {
	type = "summon-request", color1 = { r = DEFAULT_COLOR.r, g = DEFAULT_COLOR.g, b = DEFAULT_COLOR.b, a = DEFAULT_COLOR.a },
})

ns.OnGrid2Options(function()
	local Options = Grid2Options
	Options:RegisterStatusOptions("summon-request", "misc", function(self, st, options)
		options.info = {
			type = "description", order = 1,
			name = function()
				return RaidSummon and "" or "|cffff8000The RaidSummon addon is not loaded, so this status will never be active.|r"
			end,
		}
		self:MakeStatusColorOptions(st, options)
	end, {
		title = "Requesting Summon",
		titleDesc = "Active for group members who are on the RaidSummon addon's summon list.",
		titleIcon = "Interface\\Icons\\Spell_Shadow_Twilight",
	})
end)
