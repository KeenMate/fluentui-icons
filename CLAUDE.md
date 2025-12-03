# FluentUI Icons - Project Guide for Claude

## Project Overview

This is a Phoenix/Elixir web application that provides a searchable database of 6000+ Microsoft FluentUI System Icons. The live site is at https://fluentui-icons.keenmate.dev

## Tech Stack

- **Backend:** Elixir/Phoenix with LiveView
- **Database:** PostgreSQL with trigram search, full-text search
- **Frontend:** Tailwind CSS, Phoenix LiveView hooks
- **Icons:** Self-hosted SVGs synced daily from Microsoft's FluentUI repository

---

## Project Structure

### Core Business Logic (`lib/fluentui_icons/`)

| File | Purpose |
|------|---------|
| `icons.ex` | Main context - search, metrics tracking, popularity queries |
| `icons/icon.ex` | Icon schema - name, style, sizes, platform identifiers, SVG URL helpers |
| `icons/icon_metric.ex` | Individual copy/download action tracking |
| `icons/icon_metrics_cube.ex` | Pre-aggregated metrics (7d, 30d, all-time) |
| `icons/icon_synonym.ex` | Search synonyms (from metadata metaphors + manual) |
| `icons/search_metric.ex` | API search analytics |
| `sync/worker.ex` | Main sync orchestrator - downloads ZIP, parses, inserts |
| `sync/svg_downloader.ex` | Downloads GitHub ZIP, extracts SVGs (7zip > unzip > Erlang) |
| `sync/zip_parser.ex` | Parses metadata.json files, detects discrepancies |
| `sync/metaphor_extractor.ex` | Extracts/seeds synonyms from metadata |
| `sync/sync_run.ex` | Sync job history tracking |
| `synonyms/seeder.ex` | Seeds synonyms from `priv/synonyms.json` |
| `scheduler.ex` | Quantum scheduler (3AM sync, 4AM cube refresh) |
| `search_metrics_collector.ex` | GenServer - batches search metrics (flush every 30s or 100 entries) |
| `rate_limiter.ex` | Hammer-based API rate limiting |
| `application.ex` | Supervisor tree, startup logic, auto-sync |
| `release.ex` | Production migration utilities |

### Web Layer (`lib/fluentui_icons_web/`)

| File | Purpose |
|------|---------|
| `router.ex` | Routes - `/`, `/api/icons/search`, `/api/health`, `/api/maintenance/:task` |
| `live/icon_search_live.ex` | Main search page - grid/list view, filters, modal, metrics |
| `live/sync_discrepancies_live.ex` | Shows metadata vs file mismatches |
| `controllers/api/icon_controller.ex` | Search API - JSON, compact, text formats |
| `controllers/api/health_controller.ex` | Health check endpoint |
| `controllers/api/maintenance_controller.ex` | Admin tasks (sync, clean, cube) with API key auth |
| `controllers/icon_file_controller.ex` | Serves SVG files from `ICONS_PATH` |
| `components/platform_icons.ex` | Platform icon SVGs (iOS, Android, React, Svelte) |

### Mix Tasks (`lib/mix/tasks/`)

| Task | Purpose |
|------|---------|
| `mix icons.download` | Full sync - download ZIP, parse, insert DB, extract SVGs |
| `mix icons.clean` | Clean DB (options: `--all`, `--files`, `--yes`) |
| `mix icons.cube` | Refresh metrics cube |

### Frontend (`assets/`)

| File | Purpose |
|------|---------|
| `js/app.js` | LiveView hooks: PlatformPrefs, ViewMode, FilenameTemplate, InlineSvg, ColorPicker, SvelteColor, MetricsTracker |
| `css/app.css` | Tailwind CSS styles |

### Database Tables

| Table | Purpose |
|-------|---------|
| `icons` | Main icons (name, style, sizes[], ios/android identifiers, search_vector) |
| `icon_synonyms` | Search term mappings (icon_name_lower, style, synonym) |
| `icon_metrics` | Individual copy/download events (icon_id, action, size, platform) |
| `icon_metrics_cube` | Pre-aggregated metrics (icon_id, action, period, count) |
| `sync_runs` | Sync job history (status, counts, discrepancies) |
| `search_metrics` | API search analytics (query, filters, result_count) |

---

## Key Workflows

### Search Flow
1. User types in search box (debounced 300ms)
2. `Icons.search()` applies: full-text search + trigram similarity + LIKE + synonyms
3. Results weighted by relevance (ts_rank 2x, trigram 1x, synonym 1.5x)
4. Search metrics batched via `SearchMetricsCollector`

### Sync Flow (daily at 3AM or manual)
1. `Sync.Worker.sync_all()` creates SyncRun record
2. Downloads ZIP from `github.com/microsoft/fluentui-system-icons`
3. Extracts using 7zip > unzip > Erlang (priority order)
4. Parses `assets/*/metadata.json`, cross-references with SVG files
5. Inserts/updates icons, seeds synonyms from metaphors
6. Records discrepancies (metadata claims files that don't exist)

### Metrics Flow
1. User copies identifier or downloads SVG
2. `track_copy`/`track_download` event → `Icons.track_action()`
3. Nightly cube refresh aggregates 7d/30d/all-time counts

---

## API Reference

### Search Icons
```
GET /api/icons/search?q=pen&size=24&style=regular&limit=50&format=json
```

**Parameters:**
- `q` (required) - Search query
- `size` - Filter: 16, 20, 24, 28, 32, 48
- `style` - Filter: regular, filled, color, light
- `limit` - Max results (default 50, max 100)
- `format` - Response: json (full), compact, text (AI-friendly)

**Response Formats:**
- `json` - Full metadata with all platform identifiers
- `compact` - Minimal: name, style, url
- `text` - Plain text, one per line (token-efficient for LLMs)

### Other Endpoints
- `GET /api/health` - Returns `{"status": "ok", "icon_count": N}`
- `POST /api/maintenance/:task` - Admin (sync, clean, cube) - requires `X-API-Key` header
- `GET /icons/:style/:filename` - Serves SVG files (cached 1 year)
- `GET /llms.txt` - AI/LLM documentation

---

## Development

```bash
make install          # Install dependencies
make setup-db         # Setup database
make dev              # Start dev server at localhost:4000
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Yes | - | Phoenix secret |
| `PHX_HOST` | Yes | - | Public hostname |
| `ICONS_PATH` | No | `.icons/` | SVG storage directory |
| `MAINTENANCE_API_KEY` | No | - | API key for admin endpoints |
| `AUTO_MIGRATE` | No | `true` | Run migrations on startup |

---

## Related Projects

### MCP Server Package

Companion MCP server at **`../fluentui-icons-mcp/`**

- **npm:** `@keenmate/fluentui-icons-mcp`
- **Version:** `1.0.0`
- **Source:** `C:\Git\KM\fluentui-icons-mcp\`

Allows Claude Desktop/Code to search icons directly.

**Configuration:**
```json
{
  "mcpServers": {
    "fluentui-icons": {
      "command": "npx",
      "args": ["-y", "@keenmate/fluentui-icons-mcp"]
    }
  }
}
```

**Tools:**
- `search_icons` - Search by name, filter by style/size
- `get_icon_svg` - Fetch raw SVG content

**Build:**
```bash
cd ../fluentui-icons-mcp
npm install && npm run build
npm publish --access public
```
