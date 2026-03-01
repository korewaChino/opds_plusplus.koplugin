# Copilot Instructions for opds_plus.koplugin

## Project Overview

KOReader plugin providing an enhanced OPDS catalog browser with cover images, list/grid views,
catalog sync, and Kavita server integration. Runs on embedded e-reader devices (Kobo, Kindle, etc.).

- **Language:** Lua (LuaJIT), no build step
- **Plugin ID:** `opdsplus`, settings file: `opdsplus.lua`
- **Entry point:** `main.lua` → extends KOReader's `WidgetContainer`

## Project Structure

```
main.lua                    # Plugin entry, lifecycle, menu registration
_meta.lua                   # KOReader plugin metadata
opds_plus_version.lua       # Single source of truth for version string
config/settings.lua         # Settings persistence (wraps LuaSettings)
config/settings_menu.lua    # KOReader menu tree generation
core/                       # Business logic (no UI imports)
  browser_context.lua       # Context factory for navigation/fetch
  catalog_manager.lua       # CRUD for catalog server list
  download_manager.lua      # File downloads, path resolution
  feed_fetcher.lua          # HTTP + caching + XML parsing pipeline
  navigation_handler.lua    # OPDS feed → menu item conversion
  parser.lua                # XML parser (luxl FFI)
  state_manager.lua         # Singleton state, dirty tracking, change listeners
  sync_manager.lua          # Batch sync, filetype filtering
ui/browser.lua              # Main OPDS browser, extends OPDSCoverMenu
ui/menus/cover_menu.lua     # View dispatcher (list vs grid mixin injection)
ui/menus/list_menu.lua      # List view renderer
ui/menus/grid_menu.lua      # Grid view renderer
ui/dialogs/                 # Modal dialogs (book info, download, settings)
services/                   # External I/O (HTTP, images, Kavita API)
utils/                      # Pure utilities (Result monad, URL, file, debug)
models/constants.lua        # All constants: MIME types, icons, presets, defaults
```

## Code Style

- **Module pattern:** `local M = {} ... return M` — see [utils/result.lua](utils/result.lua)
- **Class pattern:** KOReader `Widget:extend {}` for UI; `setmetatable(o, self)` for services
- **Naming:** `snake_case` for variables/functions, `PascalCase` for module tables
- **Private functions:** prefix with `_` (e.g. `_loadVisibleCovers`)
- **Imports:** KOReader framework uses `/` paths (`"ui/widget/menu"`), plugin modules use `.` paths
  (`"core.state_manager"`)
- **i18n:** All user-visible strings use `_("...")` or `T(_("..."), var)`
- **Linting:** `.luacheckrc` configured — `luacheck *.lua core/ ui/ config/ services/ utils/ models/`
- **Loop variables:** Do NOT use `_` as a loop discard variable — `_` is the gettext function.
  Use `i` or a descriptive name instead: `for i, item in ipairs(list) do`

## Key Patterns

### State Management

Use `StateManager` singleton for all settings access. Call `markDirty()` after mutations:

```lua
local state = StateManager.getInstance()
state:setDisplayMode("grid")
state:markDirty()
```

### Result Monad

`HttpClient` and `BrowserContext.validate()` return `Result` objects — use `map`/`andThen`/`unwrapOr`:

```lua
local result = HttpClient.fetch(url, opts)
if result:isErr() then return end
local data = result:unwrapOr(default)
```

### View Mode Mixin

`OPDSCoverMenu.updateItems()` dynamically injects methods from `OPDSListMenu` or `OPDSGridMenu`
onto `self`. When modifying view-specific rendering, edit the specific menu file, not `cover_menu.lua`.

### Catalog Server Struct

```lua
{ title, url, username, password, raw_names, sync, sync_dir, last_download }
```

Fields flow through: `editCatalogFromInput` (fields array indices 1-7) → `buildRootEntry` →
`item_table` entry → `browser.root_catalog_*` properties during navigation.

### Settings Persistence

Two layers: `Settings` class (raw LuaSettings wrapper) and `StateManager` (typed accessors + dirty
tracking). Plugin settings menu uses `plugin.settings` directly with `plugin.opds_settings:flush()`.

## Development

```bash
# Lint
luacheck *.lua core/ ui/ config/ services/ utils/ models/

# Deploy to device (requires SSH alias 'kobo')
just install
```

No automated tests exist. Test manually on device per CONTRIBUTING.md checklist.

## Device Constraints

- Memory-constrained embedded devices — avoid unnecessary allocations
- Free blitbuffer images explicitly (`bb:free()`) when done
- Cache computed values; minimize file I/O
- Use `UIManager:scheduleIn()` for async work, not coroutines
