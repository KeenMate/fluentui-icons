defmodule FluentuiIcons.Repo.Migrations.AddTrigramIndex do
  use Ecto.Migration

  def change do
    # Add trigram index for fuzzy search on name
    execute(
      "CREATE INDEX icons_name_trgm_idx ON icons USING GIN(name gin_trgm_ops)",
      "DROP INDEX icons_name_trgm_idx"
    )
  end
end
