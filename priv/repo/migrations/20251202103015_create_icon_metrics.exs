defmodule FluentuiIcons.Repo.Migrations.CreateIconMetrics do
  use Ecto.Migration

  def change do
    create table(:icon_metrics) do
      add :icon_id, references(:icons, on_delete: :delete_all), null: false
      add :action, :string, null: false  # "copy" or "download"
      add :size, :integer
      add :platform, :string  # "ios", "android", "react", "svelte", "filename", etc.

      timestamps(updated_at: false)
    end

    create index(:icon_metrics, [:icon_id])
    create index(:icon_metrics, [:action])
    create index(:icon_metrics, [:inserted_at])
  end
end
