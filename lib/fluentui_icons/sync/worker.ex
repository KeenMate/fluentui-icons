defmodule FluentuiIcons.Sync.Worker do
  @moduledoc """
  Worker module that fetches and syncs FluentUI icons from GitHub.
  """

  require Logger
  alias FluentuiIcons.{Repo, Icons.Icon, Sync.Parser, Sync.SvgDownloader, Sync.SyncRun}
  import Ecto.Query

  @base_url "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main"
  @styles ~w(regular filled color light)

  @doc """
  Sync all icon styles from GitHub.

  This fetches all 4 markdown files (regular, filled, color, light) and
  updates the database with the parsed icons.

  ## Options
    * `:download_svgs` - Also download SVG files after syncing (default: true)
  """
  def sync_all(opts \\ []) do
    download_svgs = Keyword.get(opts, :download_svgs, true)
    Logger.info("Starting FluentUI icons sync...")

    # Start tracking the sync run
    {:ok, sync_run} = SyncRun.start("icon_sync")

    results =
      Enum.map(@styles, fn style ->
        case sync_style(style) do
          {:ok, count} ->
            Logger.info("Synced #{count} #{style} icons")
            {:ok, style, count}

          {:error, reason} ->
            Logger.error("Failed to sync #{style}: #{inspect(reason)}")
            {:error, style, reason}
        end
      end)

    successes = Enum.count(results, &match?({:ok, _, _}, &1))
    total = results |> Enum.filter(&match?({:ok, _, _}, &1)) |> Enum.map(&elem(&1, 2)) |> Enum.sum()
    Logger.info("Sync complete: #{successes}/#{length(@styles)} styles succeeded (#{total} total icons)")

    # Record sync completion
    if successes > 0 do
      SyncRun.complete(sync_run, %{icons_synced: total})
    else
      errors = results |> Enum.filter(&match?({:error, _, _}, &1)) |> Enum.map(&elem(&1, 2)) |> Enum.join(", ")
      SyncRun.fail(sync_run, errors)
    end

    # Download SVGs after successful sync (using ZIP method for speed)
    if download_svgs and successes > 0 do
      Logger.info("Starting SVG download from ZIP...")
      SvgDownloader.download_from_zip()
    end

    results
  end

  @doc """
  Sync a single icon style from GitHub.
  """
  def sync_style(style) when style in @styles do
    url = "#{@base_url}/icons_#{style}.md"

    with {:ok, %{status: 200, body: body}} <- Req.get(url, retry: :transient, retry_delay: 1000),
         icons when icons != [] <- Parser.parse(body, style) do
      # Delete old icons for this style and insert new ones in a transaction
      Repo.transaction(fn ->
        Repo.delete_all(from(i in Icon, where: i.style == ^style))

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        icons
        |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
        |> Enum.chunk_every(500)
        |> Enum.each(&Repo.insert_all(Icon, &1))
      end)

      {:ok, length(icons)}
    else
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, reason}
      [] -> {:error, "No icons parsed"}
    end
  end

  def sync_style(style), do: {:error, "Unknown style: #{style}"}
end
