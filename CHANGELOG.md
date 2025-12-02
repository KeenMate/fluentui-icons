# Changelog

## [Unreleased]

### Fixed
- Fix icon size parsing for numbered icons (e.g., "Music Note 1", "Calendar 3 Day") - was extracting `120` instead of `20` from iOS identifiers like `musicNote120Filled`
- Fix orphaned SVG files remaining on disk after sync - now cleans up style directories before extracting new icons
- Fix Tailwind CSS classes missing in production Docker build by reordering Dockerfile to copy `lib/` before `mix assets.deploy`
- Fix synonyms not seeding in production by using `:code.priv_dir/1` for correct path resolution in releases

### Added
- Unified sync: DB and SVG files are now treated as one atomic state
  - On startup: if either DB OR files missing → full sync (both)
  - Scheduled 3am job: full sync (both)
  - `mix icons.download`: full sync (both)
  - No more inconsistent states between DB and files
- Auto-download icons on startup: If `icons_path` is configured but empty, automatically downloads icons from GitHub ZIP
- Proper Phoenix configuration hierarchy for `icons_path`:
  - Dev default: `.icons/` in project root (git-ignored)
  - Prod: Override via `ICONS_PATH` environment variable
  - User overrides: Optional `config/.local.exs` support
- 7zip support in Docker image (`p7zip-full`) for faster icon extraction
- Optimized ZIP extraction: Only extracts `assets/` folder instead of entire repo
- Startup logging: Reports which extraction tool is available (7zip, unzip, or Erlang fallback)
- Self-hosted icons: `mix icons.download` downloads all SVGs to configured `icons_path` for local serving (performance + offline access)
- Customizable filename template in icon detail modal with placeholders ({filename}, {name}, {name_snake}, {name_pascal}, {name_kebab}, {size}, {style})
- Color picker for icon preview in modal - icons are fetched inline and fill color can be customized
- "Include color" checkbox in Svelte code generation to add custom color props
- Docker deployment support with multi-stage build
- Auto-migration on application startup (controlled by `AUTO_MIGRATE` env var)
- Grid/List view toggle with localStorage persistence
- CSS-based view mode switching to prevent flash on page load
- Thicker table headers and bolder checkmarks in list view
- Makefile with docker-build, docker-push, docker-deploy-registry commands
- Sync run tracking: `sync_runs` table records job history (type, status, icons synced, SVGs downloaded, timestamps)
- Last sync display: Footer shows "Last synced: X minutes ago" with relative time formatting
- Metaphor extraction: Automatically extract synonyms from FluentUI's `metadata.json` files during ZIP download
  - New `MetaphorExtractor` module reads metaphor arrays from icon metadata
  - Merges extracted metaphors with manual `synonyms.json`
  - Increased synonym count from 101 to 51,760 entries

### Fixed
- Fixed metaphor extraction to use `"metaphor"` (singular) key matching actual GitHub metadata schema

### Improved
- Search now finds icons via metaphor synonyms (e.g., searching "plus" finds "Add", "Add Square", "Document Add", etc.)

### Changed
- Updated README with deployment instructions
