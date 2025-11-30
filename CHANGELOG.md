# Changelog

## [Unreleased]

### Fixed
- Fix Tailwind CSS classes missing in production Docker build by reordering Dockerfile to copy `lib/` before `mix assets.deploy`
- Fix synonyms not seeding in production by using `:code.priv_dir/1` for correct path resolution in releases

### Added
- Docker deployment support with multi-stage build
- Auto-migration on application startup (controlled by `AUTO_MIGRATE` env var)
- Grid/List view toggle with localStorage persistence
- CSS-based view mode switching to prevent flash on page load
- Thicker table headers and bolder checkmarks in list view
- Makefile with docker-build, docker-push, docker-deploy-registry commands

### Changed
- Updated README with deployment instructions
