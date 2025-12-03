defmodule Mix.Tasks.Icons.Cube do
  @moduledoc """
  Refreshes the pre-aggregated metrics cube.

  ## Usage

      mix icons.cube

  This computes aggregated copy/download counts for 7d, 30d, and all-time periods.
  Run this periodically (e.g., nightly via cron) to keep the cube fresh.
  """
  use Mix.Task

  @shortdoc "Refresh the metrics cube (7d, 30d, all-time aggregations)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Refreshing metrics cube...")
    FluentuiIcons.Icons.refresh_metrics_cube()
    Mix.shell().info("Done!")
  end
end
