# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-15

### Added
- Cast statuses (`cast`): one status per tracked spell, created under Statuses > Casts > New Cast like Buffs, with spell-name suggestions while typing. Each shows on the caster's Grid2 frame for a set duration after a successful cast, through icon, color, text and bar indicators; duration, color and icon are editable (#9).
- CurseForge project assets: logo (`icon.png`), `docs/curseforge.md` and the project ID in the toc.

### Changed
- Replaces the pre-release single `cast-tracker` status; saved `cast-tracker` spell lists are converted into separate cast statuses on load. Indicator links must be set again.
- No spells are tracked by default (#3).

[Unreleased]: https://github.com/ehvd/Grid2Extensions/compare/v0.1.0...develop
[0.1.0]: https://github.com/ehvd/Grid2Extensions/compare/v0.0.1-alpha.1...v0.1.0
