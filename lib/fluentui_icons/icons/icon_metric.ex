defmodule FluentuiIcons.Icons.IconMetric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icon_metrics" do
    belongs_to :icon, FluentuiIcons.Icons.Icon
    field :action, :string  # "copy" or "download"
    field :size, :integer
    field :platform, :string  # "ios", "android", "react", "svelte", "filename", etc.

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:icon_id, :action, :size, :platform])
    |> validate_required([:icon_id, :action])
    |> validate_inclusion(:action, ~w(copy download))
  end
end
