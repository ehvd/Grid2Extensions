# Grid2 Extensions

Extra statuses for Grid2 raid frames, starting with a cast tracker.

World of Warcraft **Classic Era** addon (Interface `11509`).

## Install

Download it from [CurseForge](https://www.curseforge.com/wow/addons/grid2extensions) or the
[GitHub releases](https://github.com/ehvd/Grid2Extensions/releases).

## Development

Needs GNU make, git and [luacheck](https://github.com/lunarmodules/luacheck) (Git for Windows provides the shell tools).

```bash
make            # list the targets
make lint       # luacheck
make link       # junction the repo into the AddOns folder; /reload picks up edits
make install    # copy the addon into the AddOns folder instead
```

Put personal settings (WoW location, luacheck path) into the untracked `local.mk`:

```make
WOW_DIR  = D:/Games/World of Warcraft
LUACHECK = C:/Users/me/bin/luacheck.exe
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the git flow and releases and [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md)
for the platform limits the addon is designed around.

## License

MIT, see [LICENSE](LICENSE).
