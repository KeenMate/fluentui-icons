defmodule FluentuiIcons.Icons.SearchMetric do
  @moduledoc """
  Tracks API search endpoint usage.

  Records what users/AI search for, including filters used and result counts.
  Writes are batched via SearchMetricsCollector to avoid DB load.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "search_metrics" do
    field :query, :string
    field :size, :integer
    field :style, :string
    field :result_count, :integer

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:query, :size, :style, :result_count])
    |> validate_required([:query, :result_count])
  end
end
