defmodule FluentuiIcons.Sync.MetaphorExtractor do
  @moduledoc """
  Extracts metaphors (synonyms) from FluentUI icon metadata.json files.

  Each icon folder in the GitHub repo contains a metadata.json with:
  - name: Icon name
  - metaphors: List of related words/concepts (e.g., ["Plus", "Addition", "New"] for Add icon)

  These metaphors are extracted and merged with manual synonyms to improve search.
  """

  require Logger
  alias FluentuiIcons.Repo
  alias FluentuiIcons.Icons.IconSynonym

  @styles ~w(regular filled color light)

  @doc """
  Extract metaphors from all metadata.json files in an extracted ZIP directory.
  Returns a map of %{icon_name => [metaphors]}.
  """
  def extract_from_directory(extracted_dir) do
    # Find assets directory - ZIP extracts to fluentui-system-icons-main/assets/
    assets_dir = Path.join([extracted_dir, "fluentui-system-icons-main", "assets"])

    if File.dir?(assets_dir) do
      Logger.info("Extracting metaphors from #{assets_dir}...")

      metaphors =
        assets_dir
        |> File.ls!()
        |> Enum.filter(&File.dir?(Path.join(assets_dir, &1)))
        |> Enum.reduce(%{}, fn icon_folder, acc ->
          metadata_path = Path.join([assets_dir, icon_folder, "metadata.json"])

          case read_metadata(metadata_path) do
            {:ok, %{"name" => name, "metaphor" => metaphor}} when is_list(metaphor) and metaphor != [] ->
              Map.put(acc, name, metaphor)

            _ ->
              acc
          end
        end)

      Logger.info("Extracted metaphors for #{map_size(metaphors)} icons")
      {:ok, metaphors}
    else
      Logger.warning("Assets directory not found: #{assets_dir}")
      {:ok, %{}}
    end
  end

  defp read_metadata(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> :error
        end

      {:error, _} ->
        :error
    end
  end

  @doc """
  Seed metaphors into the icon_synonyms table.
  Merges with existing synonyms from synonyms.json.
  """
  def seed_metaphors(metaphors_map) when map_size(metaphors_map) == 0 do
    Logger.info("No metaphors to seed")
    :ok
  end

  def seed_metaphors(metaphors_map) do
    Logger.info("Seeding #{map_size(metaphors_map)} icon metaphors as synonyms...")

    # Load existing manual synonyms
    existing_synonyms = load_manual_synonyms()

    # Merge metaphors with existing synonyms
    merged = merge_synonyms(existing_synonyms, metaphors_map)

    # Seed all synonyms
    sync_synonyms(merged)

    Logger.info("Seeded metaphors for #{map_size(metaphors_map)} icons (merged with #{map_size(existing_synonyms)} manual synonyms)")
    :ok
  end

  defp load_manual_synonyms do
    synonyms_file = Path.join(:code.priv_dir(:fluentui_icons), "synonyms.json")

    case File.read(synonyms_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, map} -> map
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp merge_synonyms(manual, metaphors) do
    # Merge metaphors into manual synonyms
    # Manual synonyms take precedence, metaphors are added
    Enum.reduce(metaphors, manual, fn {icon_name, new_synonyms}, acc ->
      existing = Map.get(acc, icon_name, [])
      # Combine and deduplicate (case-insensitive)
      combined =
        (existing ++ new_synonyms)
        |> Enum.map(&String.downcase/1)
        |> Enum.uniq()

      Map.put(acc, icon_name, combined)
    end)
  end

  defp sync_synonyms(synonyms_map) do
    Repo.transaction(fn ->
      # Clear existing synonyms
      Repo.delete_all(IconSynonym)

      # Build entries
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      entries =
        for {icon_name, syns} <- synonyms_map,
            style <- @styles,
            synonym <- syns do
          %{
            icon_name_lower: String.downcase(icon_name),
            icon_style: style,
            synonym: String.downcase(synonym),
            inserted_at: now,
            updated_at: now
          }
        end

      # Bulk insert in chunks
      if entries != [] do
        entries
        |> Enum.chunk_every(1000)
        |> Enum.each(&Repo.insert_all(IconSynonym, &1, on_conflict: :nothing))
      end

      length(entries)
    end)
  end
end
