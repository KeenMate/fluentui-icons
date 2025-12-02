defmodule FluentuiIcons.Repo.Migrations.CreateSyncRuns do
  use Ecto.Migration

  def change do
    create table(:sync_runs) do
      add :job_type, :string, null: false
      add :status, :string, null: false, default: "running"
      add :icons_synced, :integer
      add :svgs_downloaded, :integer
      add :error_message, :text
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:sync_runs, [:job_type])
    create index(:sync_runs, [:status])
    create index(:sync_runs, [:completed_at])
  end
end
