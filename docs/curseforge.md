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

Shows an icon on a player's Grid2 frame for a few seconds after they successfully cast a tracked spell, using the combat
log. Meant for spells that put no buff on the caster, for example **Challenging Shout** (6 seconds).

- Create casts in the Grid2 options under **Statuses > Casts > New Cast**, the same way you create Buffs: start typing a spell name for suggestions (or enter a spell ID) and create. Nothing is tracked by default. One cast status tracks one spell ID; add one per rank if you need several.
- Each cast is its own status with its own duration (default 6 s), optional icon, Load conditions and indicator links; delete it with the icon in its title.
- Recasting refreshes the icon; leaving the group clears it.

## Links

- Source and bug reports: https://github.com/ehvd/Grid2Extensions
