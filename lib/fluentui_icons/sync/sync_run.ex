defmodule FluentuiIcons.Sync.SyncRun do
  @moduledoc """
  Schema for tracking sync job runs.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias FluentuiIcons.Repo

  schema "sync_runs" do
    field :job_type, :string
    field :status, :string, default: "running"
    field :icons_synced, :integer
    field :svgs_downloaded, :integer
    field :error_message, :string
    field :discrepancies, {:array, :map}, default: []
    field :discrepancy_count, :integer, default: 0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(sync_run, attrs) do
    sync_run
    |> cast(attrs, [:job_type, :status, :icons_synced, :svgs_downloaded, :error_message, :discrepancies, :discrepancy_count, :started_at, :completed_at])
    |> validate_required([:job_type, :status, :started_at])
    |> validate_inclusion(:status, ~w(running completed failed))
    |> validate_inclusion(:job_type, ~w(icon_sync svg_download full_sync))
  end

  @doc """
  Start a new sync run record.
  """
  def start(job_type) do
    %__MODULE__{}
    |> changeset(%{
      job_type: job_type,
      status: "running",
      started_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Mark a sync run as completed.
  """
  def complete(sync_run, attrs \\ %{}) do
    sync_run
    |> changeset(Map.merge(attrs, %{
      status: "completed",
      completed_at: DateTime.utc_now()
    }))
    |> Repo.update()
  end

  @doc """
  Mark a sync run as failed.
  """
  def fail(sync_run, error_message) do
    sync_run
    |> changeset(%{
      status: "failed",
      error_message: error_message,
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Get the last successful sync run for a job type.
  """
  def last_successful(job_type \\ nil) do
    query =
      from(r in __MODULE__,
        where: r.status == "completed",
        order_by: [desc: r.completed_at],
        limit: 1
      )

    query =
      if job_type do
        from(r in query, where: r.job_type == ^job_type)
      else
        query
      end

    Repo.one(query)
  end

  @doc """
  Get last sync timestamp (for any successful sync).
  Returns nil if no sync has been completed.
  """
  def last_sync_at do
    case last_successful() do
      nil -> nil
      run -> run.completed_at
    end
  end
end
