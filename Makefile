# Grid2Extensions development tasks. Run `make` for the list of targets.
#
# Needs GNU make plus a POSIX sh with git, cp, sed and awk (Git for Windows provides them).
# Personal settings (WoW location, luacheck path) go into the untracked local.mk, e.g.
#   WOW_DIR  = D:/Games/World of Warcraft
#   LUACHECK = C:/Users/me/bin/luacheck.exe
-include local.mk

ADDON     := Grid2Extensions
WOW_DIR   ?= C:/Program Files (x86)/Blizzard/World of Warcraft
ADDON_DIR ?= $(WOW_DIR)/_classic_era_/Interface/AddOns
LUACHECK  ?= luacheck
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

DEST          := $(ADDON_DIR)/$(ADDON)
# Everything the game needs (no docs, CI files, tests). Plugin for Grid2: no embedded libraries.
INSTALL_FILES := $(ADDON).toc Grid2Extensions.lua LICENSE

# PowerShell snippets (the path comes in through the T / S environment variables to survive spaces)
PS_EXIT_IF_LINK  = if ((Test-Path -LiteralPath $$env:T) -and ((Get-Item -LiteralPath $$env:T -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { exit 1 }
PS_EXIT_IF_EXIST = if (Test-Path -LiteralPath $$env:T) { exit 1 }
PS_MAKE_LINK     = New-Item -ItemType Junction -Path $$env:T -Target (Resolve-Path -LiteralPath $$env:S).Path | Out-Null
PS_REMOVE        = if (Test-Path -LiteralPath $$env:T) { $$i = Get-Item -LiteralPath $$env:T -Force; if ($$i.Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($$i.FullName) } else { Remove-Item -LiteralPath $$i.FullName -Recurse -Force } }

.DEFAULT_GOAL := help
.PHONY: help lint install link uninstall check-addon-dir

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'
	@echo ""
	@echo "AddOns folder: $(ADDON_DIR)"

lint: ## Run luacheck
	$(LUACHECK) .

check-addon-dir:
	@test -d "$(ADDON_DIR)" || { \
	  echo "AddOns folder not found: $(ADDON_DIR)"; \
	  echo "Set WOW_DIR (or ADDON_DIR) on the command line or in local.mk."; \
	  exit 1; }

install: check-addon-dir ## Copy the addon into the WoW AddOns folder
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_EXIT_IF_LINK)' || { \
	  echo "$(DEST) is a link created by 'make link'. Run 'make uninstall' first."; exit 1; }
	@rm -rf "$(DEST)"
	@mkdir -p "$(DEST)"
	@cp -r $(INSTALL_FILES) "$(DEST)/"
	@sed -i "s/@project-version@/$(VERSION)/" "$(DEST)/$(ADDON).toc"
	@echo "Installed $(ADDON) $(VERSION) to $(DEST). Use /reload (or restart) in game."

link: check-addon-dir ## Junction the repo into AddOns for live development (/reload picks up edits)
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_EXIT_IF_EXIST)' || { \
	  echo "$(DEST) already exists. Run 'make uninstall' first."; exit 1; }
	@T="$(DEST)" S="$(CURDIR)" powershell -NoProfile -Command '$(PS_MAKE_LINK)'
	@echo "Linked $(DEST) -> $(CURDIR). Use /reload in game after editing."

uninstall: check-addon-dir ## Remove the installed addon or the link (never touches the repo)
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_REMOVE)'
	@echo "Removed $(DEST)"
