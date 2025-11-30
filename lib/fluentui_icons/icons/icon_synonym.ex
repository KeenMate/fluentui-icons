defmodule FluentuiIcons.Icons.IconSynonym do
  use Ecto.Schema

  schema "icon_synonyms" do
    field :icon_name_lower, :string
    field :icon_style, :string
    field :synonym, :string

    timestamps()
  end
end
