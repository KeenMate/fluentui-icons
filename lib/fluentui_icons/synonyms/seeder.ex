defmodule FluentuiIcons.Synonyms.Seeder do
  @moduledoc """
  Seeds icon synonyms from priv/synonyms.json into the database.

  This runs on application startup to ensure synonyms are always in sync
  with the JSON file committed to git.
  """

  require Logger
  alias FluentuiIcons.Repo
  alias FluentuiIcons.Icons.IconSynonym

  @styles ~w(regular filled color light)

  @doc """
  Seed synonyms from JSON file into the database.

  Clears existing synonyms and inserts fresh data from the JSON file.
  Does nothing if the file doesn't exist.
  """
  def seed do
    case File.read(synonyms_file()) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, synonyms_map} ->
            sync_synonyms(synonyms_map)
            Logger.info("Seeded #{map_size(synonyms_map)} icon synonym mappings")
            :ok

          {:error, reason} ->
            Logger.error("Failed to parse synonyms.json: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :enoent} ->
        Logger.debug("No synonyms.json file found, skipping synonym seeding")
        :ok

      {:error, reason} ->
        Logger.error("Failed to read synonyms.json: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sync_synonyms(synonyms_map) do
    Repo.transaction(fn ->
      # Clear existing synonyms
      Repo.delete_all(IconSynonym)

      # Build entries - all values lowercased at insert time
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

      # Bulk insert
      if entries != [] do
        Repo.insert_all(IconSynonym, entries)
      end
    end)
  end

  # Get the correct path to synonyms.json in any environment (dev or release)
  defp synonyms_file do
    :fluentui_icons
    |> :code.priv_dir()
    |> Path.join("synonyms.json")
  end
end
