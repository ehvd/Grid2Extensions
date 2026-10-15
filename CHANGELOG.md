# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- CurseForge project assets: logo (`icon.png`) and `docs/curseforge.md` (summary, categories, description).
- CurseForge project ID in the toc.
- Cast statuses (`cast`): one status per tracked spell, created under Statuses > Casts > New Cast like Buffs, with spell-name suggestions while typing. Each shows the spell icon on the caster's Grid2 frame for a set duration after a successful cast; duration and icon are editable (#9).

### Changed
- Replaces the single `cast-tracker` status; saved `cast-tracker` spell lists are converted into separate cast statuses on load. Indicator links must be set again.
- No spells are tracked by default (#3).

[Unreleased]: https://github.com/ehvd/Grid2Extensions/commits/develop
