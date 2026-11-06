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
