<!-- CurseForge project page. Paste the "Description" section into the project description editor. -->

## Project settings

| Field | Value |
|---|---|
| Name | Grid2 Extensions |
| Game / version | World of Warcraft, Classic (1.15.x) |
| Main category | **Unit Frames** |
| Additional categories | Combat, Plug-Ins |
| Logo | `icon.png` (400x400) |
| License | MIT |
| Source / issues | https://github.com/ehvd/Grid2Extensions |

## Summary (max 250 characters)

Grid2 add-on that shows an icon on a raid frame when a player casts a buffless spell like Challenging Shout.

## Description

# Grid2 Extensions

Small add-on modules for **Grid2** (Classic Era). Requires [Grid2](https://www.curseforge.com/wow/addons/grid2).

## Casts

Shows an indicator on a player's Grid2 frame for a few seconds after they successfully cast a tracked spell, using the combat log. Works with icon, color (square, border, text color, bar color), text and bar indicators. Meant for spells that put no buff on the caster, for example **Challenging Shout** (6 seconds).

- Create casts in the Grid2 options under **Statuses > Casts > New Cast**, the same way you create Buffs: start typing a spell name for suggestions (or enter a spell ID) and create. Nothing is tracked by default. One cast status tracks one spell ID; add one per rank if you need several.
- Each cast is its own status with its own duration (default 6 s), optional icon, Load conditions and indicator links; delete it with the icon in its title.
- Recasting refreshes the icon; leaving the group clears it.

## Requests

Statuses that a **WeakAura** switches on for a group member, for example to see who asked for a Blessing of Protection.

- Create them under **Statuses > Requests > New Request**: just a name. WeakAuras refer to the status by that name. Works with icon, color, text and bar indicators.
- Drive a status from an aura's custom actions. The status stays on while the aura is shown:

```lua
-- On Show
Grid2Extensions.Trigger("Bop", sender, 0)  -- 0 = until cleared
-- On Hide
Grid2Extensions.Clear("Bop", sender)
```

  `sender` is a unit token, a player name or a GUID of someone in your group. Leave out the last number of `Trigger` to use the status' own duration (0 by default, meaning until cleared); `Clear("Bop")` without a player clears everybody.

## Requesting Summon

A status for group members who are on the summon list of the **RaidSummon** addon (optional): icon, color and text (queue position) indicators. It appears under Statuses > Miscellaneous as *summon-request*.

## Links

- Source and bug reports: https://github.com/ehvd/Grid2Extensions
