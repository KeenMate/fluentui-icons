defmodule FluentuiIcons.Repo.Migrations.AddNameLowerToIcons do
  use Ecto.Migration

  def change do
    alter table(:icons) do
      add :name_lower, :string
    end

    # Populate existing rows
    execute "UPDATE icons SET name_lower = LOWER(name)", ""

    # Add index for efficient joins with synonyms
    create index(:icons, [:name_lower, :style])
  end
end
