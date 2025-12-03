# Changelog

## [Unreleased]

### Added
- Sticky headers: Table headers and search/filter controls now stay fixed at the top when scrolling
  - Table headers (`<thead>`) stick in both icon list and sync discrepancies views
  - Search bar, filters, and view toggle stick together as a unified header section
- Platform icons: SVG icons for iOS (Apple), Android, React, Svelte, and Filename displayed throughout the UI
  - Platform toggle checkboxes in modal show platform icons
  - Platform identifier section headers include platform icons
  - Grid hover shows platform icons instead of text labels
  - List view shows platform copy buttons on row hover (overlay with icons for first 2 preferred platforms)
- Preferred platform ordering: Grid/list hover shows first 2 platforms based on user's modal selection order
- Platform usage tracking: Track which platforms users copy most frequently
- `mix icons.clean` task: Clean icons/synonyms from database for fresh reload (options: `--all`, `--files`, `--yes`)
- `mix icons.cube` task: Refresh pre-aggregated metrics cube (7d, 30d, all-time)
- ZIP-based sync: Use ZIP archive as single source of truth (eliminates version mismatch between markdown and ZIP)
- Discrepancy detection: Cross-reference metadata.json claims with actual SVG files
  - Track missing SVG files during sync
  - Discrepancy report page at `/sync/discrepancies`
  - Footer link shows discrepancy count when > 0
  - Icon names link to Microsoft GitHub repo for easy upstream verification
  - Missing file badges sorted by style (regular → filled → color → light) then size
- Maintenance API endpoint (`POST /api/maintenance/:task`) for remote task execution
  - Tasks: `sync`, `clean`, `cube`
  - API key authentication via `X-API-Key` header (set `MAINTENANCE_API_KEY` env var)
  - Rate limiting with Hammer (5 attempts per 5 minutes per IP)
  - Timing-safe key comparison to prevent timing attacks

### Fixed
- Fix copy tracking not sending events to server (MetricsTracker hook pattern)
- Fix color picker persistence when changing filters or closing modal
- Fix SVG files not copying to mounted Docker volume (use `File.copy` instead of `File.rename` for cross-filesystem support)
- Fix list view copy buttons not working (event propagation conflict with row click)
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
