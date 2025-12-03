# FluentUI Icon Search

A fast, searchable database of 6000+ Microsoft FluentUI System Icons with platform-specific identifiers for iOS, Android, React, and Svelte.

**Live:** [fluentui-icons.keenmate.dev](https://fluentui-icons.keenmate.dev)

## Features

- **Search 6000+ FluentUI icons** by name with fuzzy matching and 50k+ synonyms (extracted from FluentUI metadata)
- **Filter** by style (regular, filled, color, light) and size (16, 20, 24, 28, 32, 48)
- **Grid and list views** with size availability matrix
- **Platform identifiers** for iOS (Swift), Android (Kotlin/Java), React, and Svelte
- **Quick copy buttons** - hover over grid cards or list rows to copy platform identifiers
- **Customizable filename templates** with placeholders ({filename}, {name}, {size}, {style}, etc.)
- **Color preview** - pick custom colors for icon preview in modal
- **Platform preferences** - toggle and reorder platforms, persisted in localStorage
- **Usage tracking** - tracks copy/download stats and platform popularity
- **Self-hosted SVGs** - icons served locally for performance and offline access
- **JSON API** for programmatic access
- **Automatic daily sync** with Microsoft's FluentUI repository (ZIP-based, single source of truth)

## Development

```bash
# Install dependencies
make install

# Setup database
make setup-db

# Start dev server
make dev
```

Visit [localhost:4000](http://localhost:4000)

## Mix Tasks

```bash
# Download icons from FluentUI repository
mix icons.download

# Clean icons/synonyms from database (for fresh reload)
mix icons.clean          # icons + synonyms only
mix icons.clean --all    # also clears metrics
mix icons.clean --files  # also deletes SVG files

# Refresh metrics cube (run nightly for dashboard stats)
mix icons.cube
```

## Deployment

```bash
# Copy and configure environment
cp .env.example .env

# Build and push to registry
make docker-deploy-registry

# Run migrations
make migrate-prod
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_USERNAME` | Yes | - | PostgreSQL username |
| `DB_PASSWORD` | Yes | - | PostgreSQL password |
| `DB_HOSTNAME` | Yes | - | PostgreSQL host |
| `DB_DATABASE` | Yes | - | PostgreSQL database name |
| `SECRET_KEY_BASE` | Yes | - | Phoenix secret (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Yes | - | Public hostname (e.g., `fluentui-icons.example.com`) |
| `PORT` | No | `4000` | HTTP port |
| `ICONS_PATH` | No | - | Directory for SVG storage (e.g., `/app/icons`) |
| `AUTO_MIGRATE` | No | `true` | Run migrations on startup |
| `MAINTENANCE_API_KEY` | No | - | API key for maintenance endpoints |
| `POOL_SIZE` | No | `10` | Database connection pool size |

### Docker Compose Example

```yaml
services:
  fluentui-icons:
    image: your-registry/fluentui-icons:prod
    environment:
      - DB_USERNAME=fluentui_icons
      - DB_PASSWORD=secret
      - DB_HOSTNAME=postgres
      - DB_DATABASE=fluentui_icons
      - SECRET_KEY_BASE=your-secret-key
      - PHX_HOST=fluentui-icons.example.com
      - ICONS_PATH=/app/icons
      - MAINTENANCE_API_KEY=your-maintenance-key
    volumes:
      - ./data:/app/icons
```

### Performance Note

The Docker image includes **7zip** (`p7zip-full`) for fast ZIP extraction during icon sync. This is ~10x faster than the Erlang fallback. The sync automatically detects and uses the best available tool (7zip > unzip > Erlang).

## API

### Search Icons
```
GET /api/icons/search?q=pen&size=24&style=regular
```

### Maintenance (requires API key)
```bash
# Trigger full sync from GitHub
curl -X POST -H "X-API-Key: your-key" https://example.com/api/maintenance/sync

# Refresh metrics cube
curl -X POST -H "X-API-Key: your-key" https://example.com/api/maintenance/cube

# Clean icons from database
curl -X POST -H "X-API-Key: your-key" https://example.com/api/maintenance/clean
```

## Built With

- [Phoenix](https://phoenixframework.org/) / [LiveView](https://hexdocs.pm/phoenix_live_view)
- [PostgreSQL](https://www.postgresql.org/) with trigram search
- [Tailwind CSS](https://tailwindcss.com/)

## License

MIT
