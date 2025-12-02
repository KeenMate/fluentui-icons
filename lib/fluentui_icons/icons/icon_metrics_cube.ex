defmodule FluentuiIcons.Icons.IconMetricsCube do
  @moduledoc """
  Pre-aggregated metrics cube for fast dashboard queries.

  Stores computed totals for different time periods (7d, 30d, all-time).
  Refreshed nightly by the scheduler.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "icon_metrics_cube" do
    belongs_to :icon, FluentuiIcons.Icons.Icon
    field :action, :string  # "copy" or "download"
    field :period, :string  # "7d", "30d", "all"
    field :count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(cube, attrs) do
    cube
    |> cast(attrs, [:icon_id, :action, :period, :count])
    |> validate_required([:icon_id, :action, :period, :count])
    |> validate_inclusion(:action, ~w(copy download))
    |> validate_inclusion(:period, ~w(7d 30d all))
    |> unique_constraint([:icon_id, :action, :period])
  end
end
