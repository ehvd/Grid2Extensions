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

Extra statuses for Grid2 raid frames. Includes a Cast Tracker that shows an icon on a player's frame when they cast a spell that leaves no buff, such as Challenging Shout.

## Description

# Grid2 Extensions

Small add-on modules for **Grid2** (Classic Era). Requires [Grid2](https://www.curseforge.com/wow/addons/grid2).

## Cast Tracker

Shows an icon on a player's Grid2 frame for a few seconds after they successfully cast a tracked spell, using the combat
log. Meant for spells that put no buff on the caster, for example **Challenging Shout** (6 seconds).

- Appears in the Grid2 options under **Statuses > Combat** as *cast-tracker*; link it to an icon indicator.
- Spells, icons and durations are listed in one table at the top of `Grid2Extensions.lua`.
- Recasting refreshes the icon; leaving the group clears it.

## Links

- Source and bug reports: https://github.com/ehvd/Grid2Extensions
