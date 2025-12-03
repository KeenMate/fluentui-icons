defmodule FluentuiIcons.Repo.Migrations.AddDiscrepanciesToSyncRuns do
  use Ecto.Migration

  def change do
    alter table(:sync_runs) do
      add :discrepancies, :jsonb, default: "[]"
      add :discrepancy_count, :integer, default: 0
    end
  end
end
