defmodule Mix.Tasks.Icons.Download do
  @moduledoc """
  Performs a full sync of FluentUI icons (database + files).

  ## Usage

      mix icons.download

  This syncs icon metadata to the database from GitHub markdown files,
  then downloads all SVG files from the GitHub ZIP archive.

  Icons are downloaded to the path configured via `config :fluentui_icons, icons_path: "..."`.
  In dev, this defaults to `.icons/` in the project root.
  In prod, set the ICONS_PATH environment variable.
  """
  use Mix.Task

  @shortdoc "Full sync of FluentUI icons (DB + files)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Starting full sync (DB + files)...")
    FluentuiIcons.Sync.Worker.sync_all()
    Mix.shell().info("Done!")
  end
end
