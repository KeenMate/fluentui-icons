defmodule FluentuiIcons.Sync.ZipParser do
  @moduledoc """
  Parses icon metadata directly from the extracted ZIP file structure.

  Each icon folder in assets/ contains a metadata.json with:
  - name: Icon name (e.g., "Add")
  - size: Array of available sizes (e.g., [16, 20, 24, 28, 32, 48])
  - style: Array of available styles (e.g., ["Regular", "Filled"])
  - metaphor: Array of search synonyms (e.g., ["plus", "new"])

  This parser cross-references metadata with actual SVG files to ensure
  we only report sizes/styles that actually exist.
  """

  require Logger

  @doc """
  Parse all icons from an extracted ZIP directory.

  Returns:
    {:ok, %{icons: [icon_maps], metaphors: %{name => [metaphors]}, discrepancies: [discrepancy_maps]}}
  """
  def parse_from_directory(extracted_dir) do
    assets_dir = Path.join([extracted_dir, "fluentui-system-icons-main", "assets"])

    if File.dir?(assets_dir) do
      Logger.info("Parsing icons from #{assets_dir}...")

      {icons, metaphors, discrepancies} =
        assets_dir
        |> File.ls!()
        |> Enum.filter(&File.dir?(Path.join(assets_dir, &1)))
        |> Enum.reduce({[], %{}, []}, fn icon_folder, {icons_acc, meta_acc, disc_acc} ->
          icon_path = Path.join(assets_dir, icon_folder)

          case parse_icon_folder(icon_path) do
            {:ok, parsed_icons, name, icon_metaphors, icon_discrepancies} ->
              meta_acc = if icon_metaphors != [], do: Map.put(meta_acc, name, icon_metaphors), else: meta_acc
              {icons_acc ++ parsed_icons, meta_acc, disc_acc ++ icon_discrepancies}

            :skip ->
              {icons_acc, meta_acc, disc_acc}
          end
        end)

      Logger.info("Parsed #{length(icons)} icon variants from #{map_size(metaphors)} icon families")
      if length(discrepancies) > 0 do
        Logger.warning("Found #{length(discrepancies)} metadata discrepancies (missing SVG files)")
      end
      {:ok, %{icons: icons, metaphors: metaphors, discrepancies: discrepancies}}
    else
      Logger.warning("Assets directory not found: #{assets_dir}")
      {:error, "Assets directory not found"}
    end
  end

  defp parse_icon_folder(icon_path) do
    metadata_path = Path.join(icon_path, "metadata.json")
    svg_dir = Path.join(icon_path, "SVG")

    case read_metadata(metadata_path) do
      {:ok, metadata} ->
        name = metadata["name"]
        claimed_sizes = metadata["size"] || []
        claimed_styles = metadata["style"] || []
        metaphors = metadata["metaphor"] || []

        if name && claimed_sizes != [] && claimed_styles != [] do
          # Get actual SVG files
          actual_svgs = list_svg_files(svg_dir)

          # Build icons only for styles/sizes that actually exist
          {icons, discrepancies} = build_verified_icons(name, claimed_sizes, claimed_styles, actual_svgs)

          if icons != [] do
            {:ok, icons, name, metaphors, discrepancies}
          else
            :skip
          end
        else
          :skip
        end

      :error ->
        :skip
    end
  end

  defp read_metadata(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"name" => _} = data} -> {:ok, data}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp list_svg_files(svg_dir) do
    if File.dir?(svg_dir) do
      case File.ls(svg_dir) do
        {:ok, files} -> Enum.filter(files, &String.ends_with?(&1, ".svg"))
        _ -> []
      end
    else
      []
    end
  end

  defp build_verified_icons(name, claimed_sizes, claimed_styles, actual_svgs) do
    name_snake = to_snake_case(name)
    normalized_styles = Enum.map(claimed_styles, &String.downcase/1)

    # Build a set of actual {size, style} combinations from SVG filenames
    actual_combinations = parse_svg_combinations(actual_svgs)

    # Track discrepancies and build verified icons
    {icons, discrepancies} =
      Enum.reduce(normalized_styles, {[], []}, fn style, {icons_acc, disc_acc} ->
        # Find which sizes actually exist for this style
        actual_sizes = for {size, s} <- actual_combinations, s == style, do: size
        missing_sizes = claimed_sizes -- actual_sizes

        # Record discrepancies
        new_discrepancies =
          Enum.map(missing_sizes, fn size ->
            %{
              icon_name: name,
              style: style,
              size: size,
              issue: "missing_svg",
              expected_file: "ic_fluent_#{name_snake}_#{size}_#{style}.svg"
            }
          end)

        # Only create icon if at least one size exists
        if actual_sizes != [] do
          icon = %{
            name: name,
            name_lower: String.downcase(name),
            style: style,
            sizes: Enum.sort(actual_sizes),
            ios_identifiers: build_ios_identifiers(name, actual_sizes, style),
            android_identifiers: build_android_identifiers(name_snake, actual_sizes, style)
          }
          {[icon | icons_acc], disc_acc ++ new_discrepancies}
        else
          # Entire style is missing - record all sizes as discrepancies
          {icons_acc, disc_acc ++ new_discrepancies}
        end
      end)

    {Enum.reverse(icons), discrepancies}
  end

  defp parse_svg_combinations(svg_files) do
    # Parse filenames like ic_fluent_add_20_regular.svg -> {20, "regular"}
    svg_files
    |> Enum.flat_map(fn filename ->
      case Regex.run(~r/ic_fluent_.*_(\d+)_(regular|filled|color|light)\.svg$/, filename) do
        [_, size_str, style] -> [{String.to_integer(size_str), style}]
        _ -> []
      end
    end)
    |> MapSet.new()
  end

  defp build_ios_identifiers(name, sizes, style) do
    # Convert "Add Circle" to "addCircle" then append size and style
    camel_name = to_lower_camel_case(name)
    style_suffix = String.capitalize(style)

    sizes
    |> Enum.map(fn size ->
      {Integer.to_string(size), "#{camel_name}#{size}#{style_suffix}"}
    end)
    |> Map.new()
  end

  defp build_android_identifiers(name_snake, sizes, style) do
    # Format: ic_fluent_{name}_{size}_{style}
    sizes
    |> Enum.map(fn size ->
      {Integer.to_string(size), "ic_fluent_#{name_snake}_#{size}_#{style}"}
    end)
    |> Map.new()
  end

  defp to_lower_camel_case(name) do
    name
    |> String.split(~r/[\s_-]+/)
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      if idx == 0 do
        String.downcase(word)
      else
        String.capitalize(word)
      end
    end)
    |> Enum.join()
  end

  defp to_snake_case(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[\s-]+/, "_")
  end
end
