defmodule FluentuiIcons.Repo.Migrations.CreateIcons do
  use Ecto.Migration

  def change do
    create table(:icons) do
      add :name, :string, null: false
      add :style, :string, null: false
      add :sizes, {:array, :integer}, null: false, default: []
      add :ios_identifiers, :map, null: false, default: %{}
      add :android_identifiers, :map, null: false, default: %{}
      add :search_vector, :tsvector

      timestamps()
    end

    create unique_index(:icons, [:name, :style])
    create index(:icons, [:style])
    create index(:icons, [:sizes], using: :gin)

    # Full-text search index
    execute(
      "CREATE INDEX icons_search_idx ON icons USING GIN(search_vector)",
      "DROP INDEX icons_search_idx"
    )

    # Trigger function for auto-updating search_vector
    execute(
      """
      CREATE OR REPLACE FUNCTION icons_search_vector_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector := to_tsvector('english', NEW.name);
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION IF EXISTS icons_search_vector_update()"
    )

    # Trigger to call the function
    execute(
      """
      CREATE TRIGGER icons_search_vector_trigger
      BEFORE INSERT OR UPDATE ON icons
      FOR EACH ROW EXECUTE FUNCTION icons_search_vector_update();
      """,
      "DROP TRIGGER IF EXISTS icons_search_vector_trigger ON icons"
    )
  end
end
