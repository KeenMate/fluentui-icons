defmodule FluentuiIcons.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Run migrations on startup in production
    migrate()

    children = [
      # Start the Ecto repository
      FluentuiIcons.Repo,
      # Start the Telemetry supervisor
      FluentuiIconsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: FluentuiIcons.PubSub},
      # Start the rate limiter for API protection
      {FluentuiIcons.RateLimiter, clean_period: :timer.minutes(1)},
      # Start the search metrics collector (batched DB writes)
      FluentuiIcons.SearchMetricsCollector,
      # Start the Quantum scheduler
      FluentuiIcons.Scheduler,
      # Start the Endpoint (http/https)
      FluentuiIconsWeb.Endpoint,
      # Start initial sync task (async, non-blocking)
      {Task, &maybe_initial_sync/0}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FluentuiIcons.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp migrate do
    # Only auto-migrate in production releases
    if Application.get_env(:fluentui_icons, :auto_migrate, false) do
      require Logger
      Logger.info("Running database migrations...")
      FluentuiIcons.Release.migrate()
    end
  end

  # Sync icons from GitHub if either DB or files are missing
  # DB and files are treated as one atomic state
  defp maybe_initial_sync do
    require Logger

    # Log available extraction tools
    FluentuiIcons.Sync.SvgDownloader.log_extraction_tools()

    # Small delay to ensure database is ready
    Process.sleep(2000)

    db_empty = FluentuiIcons.Icons.count() == 0
    files_empty = not FluentuiIcons.Sync.SvgDownloader.icons_downloaded?()

    cond do
      db_empty and files_empty ->
        Logger.info("DB and files empty, starting full sync...")
        FluentuiIcons.Sync.Worker.sync_all()

      db_empty ->
        Logger.info("DB empty (files present), starting full sync...")
        FluentuiIcons.Sync.Worker.sync_all()

      files_empty ->
        Logger.info("Files empty (DB present), starting full sync...")
        FluentuiIcons.Sync.Worker.sync_all()

      true ->
        Logger.info("DB and files present, skipping initial sync")
    end

    # Always seed synonyms from JSON file
    FluentuiIcons.Synonyms.Seeder.seed()
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FluentuiIconsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
