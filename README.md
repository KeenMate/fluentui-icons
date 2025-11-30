# FluentUI Icon Search

A fast, searchable database of 6000+ Microsoft FluentUI System Icons with platform-specific identifiers for iOS, Android, React, and Svelte.

**Live:** [fluentui-icons.keenmate.dev](https://fluentui-icons.keenmate.dev)

## Features

- Search 6000+ FluentUI icons by name with fuzzy matching and synonyms
- Filter by style (regular, filled, color, light) and size (16, 20, 24, 28, 32, 48)
- Grid and list view with size availability matrix
- Platform identifiers for iOS (Swift), Android (Kotlin/Java), React, and Svelte
- Copy-to-clipboard for all identifiers
- SVG URLs for direct use
- JSON API for programmatic access
- Automatic daily sync with Microsoft's FluentUI repository

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

## Deployment

```bash
# Copy and configure environment
cp .env.example .env

# Build and push to registry
make docker-deploy-registry

# Run migrations
make migrate-prod
```

## API

```
GET /api/icons/search?q=pen&size=24&style=regular
```

## Built With

- [Phoenix](https://phoenixframework.org/) / [LiveView](https://hexdocs.pm/phoenix_live_view)
- [PostgreSQL](https://www.postgresql.org/) with trigram search
- [Tailwind CSS](https://tailwindcss.com/)

## License

MIT
