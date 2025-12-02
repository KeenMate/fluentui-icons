defmodule FluentuiIcons.Sync.Parser do
  @moduledoc """
  Parses FluentUI icon markdown files from GitHub.

  The markdown files have a table format:
  |Name|Icon|iOS|Android|
  |---|---|---|---|
  |Add|<img src="...">|`add20Regular`<br />`add24Regular`|`ic_fluent_add_20_regular`<br />...|
  """

  # Regex to extract table rows: Name | <img...> | iOS identifiers | Android identifiers
  @row_regex ~r/\|\s*([^|]+?)\s*\|[^|]+\|([^|]+)\|([^|]+)\|/

  @doc """
  Parse a markdown file content and extract icon data.

  ## Parameters
    * `markdown` - Raw markdown content
    * `style` - Icon style (e.g., "regular", "filled", "color", "light")

  ## Returns
    List of maps with icon data ready for database insertion.
  """
  def parse(markdown, style) do
    markdown
    |> String.split("\n")
    |> Enum.drop(2)
    |> Enum.flat_map(&parse_row(&1, style))
  end

  defp parse_row(line, style) do
    case Regex.run(@row_regex, line) do
      [_, name, ios_cell, android_cell] ->
        ios = extract_identifiers(ios_cell)
        android = extract_identifiers(android_cell)
        sizes = extract_sizes(ios)

        name = String.trim(name)

        if Enum.empty?(sizes) or name == "" or name == "Name" do
          []
        else
          [
            %{
              name: name,
              name_lower: String.downcase(name),
              style: style,
              sizes: sizes,
              ios_identifiers: ios,
              android_identifiers: android
            }
          ]
        end

      _ ->
        []
    end
  end

  defp extract_identifiers(cell) do
    # Extract identifiers from backtick-wrapped strings, separated by <br />
    ~r/`([^`]+)`/
    |> Regex.scan(cell)
    |> Enum.reduce(%{}, fn [_, id], acc ->
      # Extract size number from identifier (e.g., "20" from "add20Regular" or "musicNote120Filled")
      # FluentUI sizes are always 2 digits (10, 12, 16, 20, 24, 28, 32, 40, 48)
      # Match 2 digits immediately before the style suffix
      case Regex.run(~r/(\d{2})(?:Regular|Filled|Color|Light)$/i, id) do
        [_, size] -> Map.put(acc, size, id)
        _ -> acc
      end
    end)
  end

  defp extract_sizes(ios_map) do
    ios_map
    |> Map.keys()
    |> Enum.map(&String.to_integer/1)
    |> Enum.sort()
  end
end
