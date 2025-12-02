defmodule FluentuiIcons.Repo.Migrations.CreateIconMetricsCube do
  use Ecto.Migration

  def change do
    create table(:icon_metrics_cube) do
      add :icon_id, references(:icons, on_delete: :delete_all), null: false
      add :action, :string, null: false  # "copy" or "download"
      add :period, :string, null: false  # "7d", "30d", "all"
      add :count, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:icon_metrics_cube, [:icon_id, :action, :period])
    create index(:icon_metrics_cube, [:period, :count])
  end
end
