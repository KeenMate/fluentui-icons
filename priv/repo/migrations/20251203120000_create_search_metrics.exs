defmodule FluentuiIcons.Repo.Migrations.CreateSearchMetrics do
  use Ecto.Migration

  def change do
    create table(:search_metrics) do
      add :query, :string, null: false
      add :size, :integer
      add :style, :string
      add :result_count, :integer, null: false

      timestamps(updated_at: false)
    end

    create index(:search_metrics, [:inserted_at])
    create index(:search_metrics, [:query])
  end
end
