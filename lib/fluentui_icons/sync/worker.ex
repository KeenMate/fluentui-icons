defmodule FluentuiIcons.Sync.Worker do
  @moduledoc """
  Worker module that syncs FluentUI icons from GitHub.

  Uses a single ZIP download as the source of truth to ensure consistency
  between the icon database and SVG files.
  """

  require Logger
  alias FluentuiIcons.{Repo, Icons.Icon}
  alias FluentuiIcons.Sync.{SvgDownloader, SyncRun, MetaphorExtractor}
  import Ecto.Query

  @styles ~w(regular filled color light)

  @doc """
  Sync all icons from GitHub using the ZIP file as single source of truth.

  This downloads the ZIP once, parses icons from metadata.json files,
  extracts SVGs, and updates the database - ensuring everything is consistent.
  """
  def sync_all(_opts \\ []) do
    Logger.info("Starting FluentUI icons sync (unified ZIP method)...")

    {:ok, sync_run} = SyncRun.start("full_sync")

    case SvgDownloader.download_and_parse() do
      {:ok, %{icons: icons, metaphors: metaphors, svg_count: svg_count, discrepancies: discrepancies}} ->
        Logger.info("ZIP processed: #{length(icons)} icon variants, #{svg_count} SVGs")

        # Insert icons to database
        icon_count = insert_icons(icons)
        Logger.info("Inserted #{icon_count} icons to database")

        # Seed metaphors as synonyms
        if map_size(metaphors) > 0 do
          Logger.info("Seeding #{map_size(metaphors)} icon metaphors as synonyms...")
          MetaphorExtractor.seed_metaphors(metaphors)
        end

        # Log discrepancies
        if length(discrepancies) > 0 do
          Logger.warning("Found #{length(discrepancies)} metadata discrepancies (missing SVG files)")
        end

        SyncRun.complete(sync_run, %{
          icons_synced: icon_count,
          svgs_downloaded: svg_count,
          discrepancies: discrepancies,
          discrepancy_count: length(discrepancies)
        })
        Logger.info("Sync complete!")

        {:ok, %{icons: icon_count, svgs: svg_count, synonyms: map_size(metaphors), discrepancies: length(discrepancies)}}

      {:error, reason} ->
        Logger.error("Sync failed: #{inspect(reason)}")
        SyncRun.fail(sync_run, inspect(reason))
        {:error, reason}
    end
  end

  defp insert_icons(icons) do
    Repo.transaction(fn ->
      # Clear all existing icons
      Repo.delete_all(Icon)

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      icons
      |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
      |> Enum.chunk_every(500)
      |> Enum.each(&Repo.insert_all(Icon, &1))
    end)

    length(icons)
  end

  @doc """
  Sync a single icon style from GitHub.
  Note: This still uses the unified ZIP method but filters by style.
  For full sync, use sync_all/0.
  """
  def sync_style(style) when style in @styles do
    Logger.info("Syncing #{style} icons (uses full ZIP download)...")

    case SvgDownloader.download_and_parse() do
      {:ok, %{icons: icons, metaphors: metaphors}} ->
        style_icons = Enum.filter(icons, &(&1.style == style))

        Repo.transaction(fn ->
          Repo.delete_all(from(i in Icon, where: i.style == ^style))

          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          style_icons
          |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
          |> Enum.chunk_every(500)
          |> Enum.each(&Repo.insert_all(Icon, &1))
        end)

        # Also seed metaphors
        if map_size(metaphors) > 0 do
          MetaphorExtractor.seed_metaphors(metaphors)
        end

        {:ok, length(style_icons)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sync_style(style), do: {:error, "Unknown style: #{style}"}
end
