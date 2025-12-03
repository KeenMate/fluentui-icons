defmodule Mix.Tasks.Icons.Clean do
  @moduledoc """
  Cleans all icon-related data from the database.

  ## Usage

      mix icons.clean           # Clean icons and synonyms only
      mix icons.clean --all     # Clean everything including metrics and sync runs
      mix icons.clean --files   # Also delete downloaded SVG files

  ## Options

    * `--all` - Also clean metrics tables (icon_metrics, icon_metrics_cube) and sync_runs
    * `--files` - Also delete downloaded SVG files from disk
    * `--yes` - Skip confirmation prompt
  """
  use Mix.Task

  alias FluentuiIcons.Repo
  alias FluentuiIcons.Icons.{Icon, IconSynonym, IconMetric, IconMetricsCube}
  alias FluentuiIcons.Sync.SyncRun

  @shortdoc "Clean icons and synonyms from database"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [all: :boolean, files: :boolean, yes: :boolean])

    clean_all? = opts[:all] || false
    clean_files? = opts[:files] || false
    skip_confirm? = opts[:yes] || false

    tables = ["icons", "icon_synonyms"]
    tables = if clean_all?, do: tables ++ ["icon_metrics", "icon_metrics_cube", "sync_runs"], else: tables

    Mix.shell().info("This will delete all data from: #{Enum.join(tables, ", ")}")
    if clean_files?, do: Mix.shell().info("This will also delete all downloaded SVG files.")

    if skip_confirm? or Mix.shell().yes?("Are you sure you want to continue?") do
      Mix.Task.run("app.start")
      do_clean(clean_all?, clean_files?)
      Mix.shell().info("Done!")
    else
      Mix.shell().info("Aborted.")
    end
  end

  defp do_clean(clean_all?, clean_files?) do
    # Clean in order respecting foreign key constraints
    Mix.shell().info("Cleaning synonyms...")
    {count, _} = Repo.delete_all(IconSynonym)
    Mix.shell().info("  Deleted #{count} synonyms")

    if clean_all? do
      Mix.shell().info("Cleaning metrics cube...")
      {count, _} = Repo.delete_all(IconMetricsCube)
      Mix.shell().info("  Deleted #{count} cube entries")

      Mix.shell().info("Cleaning metrics...")
      {count, _} = Repo.delete_all(IconMetric)
      Mix.shell().info("  Deleted #{count} metrics")
    end

    Mix.shell().info("Cleaning icons...")
    {count, _} = Repo.delete_all(Icon)
    Mix.shell().info("  Deleted #{count} icons")

    if clean_all? do
      Mix.shell().info("Cleaning sync runs...")
      {count, _} = Repo.delete_all(SyncRun)
      Mix.shell().info("  Deleted #{count} sync runs")
    end

    if clean_files? do
      clean_svg_files()
    end
  end

  defp clean_svg_files do
    icons_path = Application.get_env(:fluentui_icons, :icons_path, ".icons")

    if File.exists?(icons_path) do
      Mix.shell().info("Deleting SVG files from #{icons_path}...")
      File.rm_rf!(icons_path)
      Mix.shell().info("  Deleted #{icons_path}")
    else
      Mix.shell().info("No SVG directory found at #{icons_path}")
    end
  end
end
