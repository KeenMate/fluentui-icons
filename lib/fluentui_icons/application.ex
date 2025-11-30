defmodule FluentuiIcons.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      FluentuiIcons.Repo,
      # Start the Telemetry supervisor
      FluentuiIconsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: FluentuiIcons.PubSub},
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

  # Sync icons from GitHub if the database is empty, then seed synonyms
  defp maybe_initial_sync do
    # Small delay to ensure database is ready
    Process.sleep(2000)

    case FluentuiIcons.Icons.count() do
      0 ->
        require Logger
        Logger.info("Database empty, starting initial icon sync from GitHub...")
        FluentuiIcons.Sync.Worker.sync_all()

      count ->
        require Logger
        Logger.info("Found #{count} icons in database, skipping initial sync")
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
