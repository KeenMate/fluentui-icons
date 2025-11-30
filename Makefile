# FluentUI Icons Search - Makefile
# Development and build commands for the FluentUI icons search project

# === Configuration ===
# Docker image settings
DOCKER_IMAGE_NAME = registry.km8.es/fluentui-icons
DOCKER_TAG = production
DOCKER_CONTAINER_NAME = fluentui-icons
DOCKER_PORT = 4000

# Development settings
DEV_PORT = 4000

.PHONY: help install dev build clean docker-build docker-run docker-stop docker-restart docker-logs docker-clean docker-deploy docker-push status migrate

# Default target
help: ## Show this help message
	@echo "FluentUI Icons Search - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development commands
install: ## Install all dependencies
	mix deps.get
	cd assets && npm install

dev: ## Start development server
	mix phx.server

build: ## Build for production
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix release

# Database commands
migrate: ## Run database migrations
	mix ecto.migrate

migrate-prod: ## Run database migrations in production container
	docker exec $(DOCKER_CONTAINER_NAME) /app/bin/migrate

setup-db: ## Create and migrate database
	mix ecto.create
	mix ecto.migrate

reset-db: ## Reset database (drop, create, migrate)
	mix ecto.reset

# Cleanup
clean: ## Clean build artifacts
	rm -rf _build/
	rm -rf priv/static/assets/

clean-all: clean ## Clean everything including deps
	rm -rf deps/
	rm -rf assets/node_modules/

# Docker commands
docker-build: ## Build Docker image
	@echo "Building Docker image: $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)"
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) .
	@echo "Docker image built successfully!"

docker-run: ## Run Docker container
	@echo "Starting Docker container on port $(DOCKER_PORT)"
	@if [ $$(docker ps -q -f name=$(DOCKER_CONTAINER_NAME)) ]; then \
		echo "Container is already running at http://localhost:$(DOCKER_PORT)"; \
	elif [ $$(docker ps -aq -f name=$(DOCKER_CONTAINER_NAME)) ]; then \
		echo "Starting existing container"; \
		docker start $(DOCKER_CONTAINER_NAME); \
		echo "Application is running at: http://localhost:$(DOCKER_PORT)"; \
	else \
		echo "Creating and starting new container"; \
		docker compose up -d; \
		echo "Application is running at: http://localhost:$(DOCKER_PORT)"; \
	fi

docker-stop: ## Stop Docker container
	@echo "Stopping Docker container"
	@if [ $$(docker ps -q -f name=$(DOCKER_CONTAINER_NAME)) ]; then \
		docker compose down; \
		echo "Container stopped successfully"; \
	else \
		echo "Container is not running"; \
	fi

docker-restart: docker-stop docker-run ## Restart Docker container

docker-logs: ## Show Docker container logs
	docker compose logs -f

docker-clean: docker-stop ## Remove Docker container and image
	@echo "Cleaning up Docker resources"
	@if [ $$(docker ps -aq -f name=$(DOCKER_CONTAINER_NAME)) ]; then \
		docker rm $(DOCKER_CONTAINER_NAME); \
		echo "Container removed"; \
	fi
	@if [ $$(docker images -q $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)) ]; then \
		docker rmi $(DOCKER_IMAGE_NAME):$(DOCKER_TAG); \
		echo "Image removed"; \
	fi

docker-deploy: docker-build docker-run ## Build and run Docker container

docker-push: ## Push Docker image to registry
	@echo "Pushing Docker image: $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)"
	docker push $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)
	@echo "Docker image pushed successfully!"

docker-deploy-registry: docker-build docker-push ## Build and push Docker image to registry

# Development workflows
setup: install setup-db ## Complete project setup
	@echo "Project setup complete!"
	@echo "Run 'make dev' to start development server"

fresh-start: clean install setup-db dev ## Clean setup and start development

# Information
status: ## Show project status
	@echo "FluentUI Icons Search Status:"
	@echo "Elixir version: $(shell elixir --version | head -1)"
	@echo "Mix version: $(shell mix --version)"
	@echo "Project directory: $(shell pwd)"
	@echo "Dependencies installed: $(shell test -d deps && echo "✓" || echo "✗")"
	@echo "Assets installed: $(shell test -d assets/node_modules && echo "✓" || echo "✗")"
	@echo "Build exists: $(shell test -d _build/prod && echo "✓" || echo "✗")"

info: status ## Alias for status
