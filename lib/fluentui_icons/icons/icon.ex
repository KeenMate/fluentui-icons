defmodule FluentuiIcons.Icons.Icon do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icons" do
    field :name, :string
    field :name_lower, :string
    field :style, :string
    field :sizes, {:array, :integer}
    field :ios_identifiers, :map
    field :android_identifiers, :map
    field :search_vector, :any, virtual: true

    timestamps()
  end

  @doc false
  def changeset(icon, attrs) do
    icon
    |> cast(attrs, [:name, :name_lower, :style, :sizes, :ios_identifiers, :android_identifiers])
    |> validate_required([:name, :style, :sizes])
    |> validate_inclusion(:style, ~w(regular filled color light))
    |> unique_constraint([:name, :style])
  end

  @doc """
  Generate SVG URL for an icon at a specific size.

  ## Examples

      iex> Icon.svg_url(%Icon{name: "Add", style: "regular"}, 24)
      "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Add/SVG/ic_fluent_add_24_regular.svg"
  """
  def svg_url(%__MODULE__{name: name, style: style}, size) do
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")
    "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/#{name}/SVG/ic_fluent_#{slug}_#{size}_#{style}.svg"
  end
end
