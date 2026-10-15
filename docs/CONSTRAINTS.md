# Platform constraints

Verified against the Grid2 2.9.33 source (Classic Era, Interface `11509`) on 2026-10-15.

## 1. The combat log has no event payload

`COMBAT_LOG_EVENT_UNFILTERED` passes no arguments; read them with `CombatLogGetCurrentEventInfo()`. Spell IDs differ
per rank in Classic, so every rank of a tracked spell needs its own entry in the tracked spell list.

## 2. Timers cannot be cancelled

`C_Timer.After` returns no handle. Each icon entry is a table, and its timer only clears the entry it created, so a
second cast during the duration is not cut short by the first timer.

## 3. Grid2 API used

- `Grid2.statusPrototype:new`, `Grid2.setupFunc[type]`, `Grid2:RegisterStatus(status, {"icon"}, baseKey, dbx)`,
  `status:Inject`, `status:UpdateIndicators(unit)`, `Grid2:GetUnitOfGUID(guid)` (party/raid only).
- Grid2 has no `GetUnitidByGUID` and no `Grid2:RegisterStatusType`; the names are different in this Grid2 version.
- Grid2Options is load-on-demand: the "Casts" category, the `cast` status options and a wrapper of `GetStatusInfo` (for the spell icon in the tree) are registered on its `ADDON_LOADED`.
- One `cast` status per tracked cast, all fed by one combat-log frame in this addon.
