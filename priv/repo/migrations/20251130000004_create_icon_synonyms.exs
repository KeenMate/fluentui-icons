defmodule FluentuiIcons.Repo.Migrations.CreateIconSynonyms do
  use Ecto.Migration

  def change do
    create table(:icon_synonyms) do
      add :icon_name_lower, :string, null: false
      add :icon_style, :string, null: false
      add :synonym, :string, null: false

      timestamps()
    end

    create unique_index(:icon_synonyms, [:icon_name_lower, :icon_style, :synonym])
    create index(:icon_synonyms, [:synonym])
  end
end
