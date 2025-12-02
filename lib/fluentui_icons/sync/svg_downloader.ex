defmodule FluentuiIcons.Sync.SvgDownloader do
  @moduledoc """
  Downloads SVG files from GitHub to local storage for self-hosting.
  """

  require Logger
  alias FluentuiIcons.{Repo, Icons.Icon}
  alias FluentuiIcons.Sync.MetaphorExtractor

  @github_zip_url "https://github.com/microsoft/fluentui-system-icons/archive/refs/heads/main.zip"
  @valid_styles ~w(regular filled color light)

  @doc """
  Download all SVGs by fetching the GitHub repo ZIP (recommended).
  Much faster than individual downloads - one ~200MB download instead of 19k+ requests.
  """
  def download_from_zip do
    dir = output_dir()
    Logger.info("Downloading FluentUI icons ZIP to #{dir}...")

    # Create temp file for ZIP
    temp_zip = Path.join(System.tmp_dir!(), "fluentui-icons-#{:os.system_time(:millisecond)}.zip")

    try do
      # Download ZIP
      Logger.info("Fetching ZIP from GitHub (this may take a minute)...")
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("ZIP downloaded, extracting SVGs...")
          extract_svgs_from_zip(temp_zip, dir)

        {:ok, %{status: status}} ->
          {:error, "Failed to download ZIP: HTTP #{status}"}

        {:error, reason} ->
          {:error, "Failed to download ZIP: #{inspect(reason)}"}
      end
    after
      # Cleanup temp file
      File.rm(temp_zip)
    end
  end

  defp extract_svgs_from_zip(zip_path, output_dir) do
    # Clean up existing icons to remove orphaned files
    Logger.info("Cleaning up existing icons in #{output_dir}...")
    for style <- @valid_styles do
      style_dir = Path.join(output_dir, style)
      # Remove and recreate to ensure clean state
      File.rm_rf(style_dir)
      File.mkdir_p!(style_dir)
    end

    # Create temp directory for extraction
    temp_dir = Path.join(System.tmp_dir!(), "fluentui-extract-#{:os.system_time(:millisecond)}")
    File.mkdir_p!(temp_dir)

    try do
      # Prefer 7zip > unzip > Erlang (7zip is fastest and most reliable on Windows)
      result = case find_7zip() do
        {:ok, path} ->
          Logger.info("Using 7zip (fastest)...")
          extract_with_7zip(path, zip_path, temp_dir, output_dir)

        :not_found ->
          case System.find_executable("unzip") do
            nil ->
              Logger.info("Using Erlang :zip (slower). Install '7z' or 'unzip' for faster extraction.")
              extract_with_erlang_zip(zip_path, temp_dir, output_dir)

            _unzip ->
              Logger.info("Using system unzip...")
              extract_with_system_unzip(zip_path, temp_dir, output_dir)
          end
      end

      # Extract metaphors from metadata.json files before cleanup
      case result do
        {:ok, _count} ->
          Logger.info("Extracting metaphors from metadata.json files...")
          case MetaphorExtractor.extract_from_directory(temp_dir) do
            {:ok, metaphors} when map_size(metaphors) > 0 ->
              MetaphorExtractor.seed_metaphors(metaphors)
            _ ->
              :ok
          end
        _ ->
          :ok
      end

      result
    after
      # Cleanup temp directory
      File.rm_rf(temp_dir)
    end
  end

  @doc """
  Find 7zip executable - check PATH and standard Windows locations.
  Returns {:ok, path} or :not_found.
  """
  def find_7zip do
    cond do
      exe = System.find_executable("7z") ->
        {:ok, exe}

      File.exists?("C:/Program Files/7-Zip/7z.exe") ->
        {:ok, "C:/Program Files/7-Zip/7z.exe"}

      File.exists?("C:/Program Files (x86)/7-Zip/7z.exe") ->
        {:ok, "C:/Program Files (x86)/7-Zip/7z.exe"}

      true ->
        :not_found
    end
  end

  @doc """
  Log available extraction tools on startup.
  """
  def log_extraction_tools do
    case find_7zip() do
      {:ok, path} ->
        Logger.info("7zip found at: #{path}")
      :not_found ->
        case System.find_executable("unzip") do
          nil ->
            Logger.warning("No 7zip or unzip found - will use slow Erlang :zip for extraction")
          path ->
            Logger.info("unzip found at: #{path} (7zip not found)")
        end
    end
  end

  defp extract_with_7zip(exe_path, zip_path, temp_dir, output_dir) do
    # 7zip: x = extract with paths, -o = output dir (no space!), -y = yes to all
    # Only extract assets folder (contains SVGs and metadata.json files)
    Logger.info("Running 7zip: #{exe_path} x #{zip_path} -o#{temp_dir} assets/* -y")
    {output, exit_code} = System.cmd(exe_path, [
      "x",
      zip_path,
      "-o#{temp_dir}",
      "fluentui-system-icons-main/assets/*",
      "-y"
    ], stderr_to_stdout: true)

    Logger.info("7zip exit code: #{exit_code}")
    Logger.debug("7zip output: #{String.slice(output, 0, 500)}")

    if exit_code != 0 do
      {:error, "7zip failed (exit #{exit_code}): #{output}"}
    else
      # Debug: list directory structure
      case File.ls(temp_dir) do
        {:ok, contents} ->
          Logger.info("Temp dir contents (#{length(contents)} items): #{Enum.take(contents, 5) |> inspect}")
          # List nested assets folder if it exists
          repo_dir = Path.join(temp_dir, "fluentui-system-icons-main")
          if File.dir?(repo_dir) do
            case File.ls(repo_dir) do
              {:ok, repo_contents} ->
                Logger.info("Repo dir contents: #{Enum.take(repo_contents, 10) |> inspect}")
                assets_dir = Path.join(repo_dir, "assets")
                if File.dir?(assets_dir) do
                  case File.ls(assets_dir) do
                    {:ok, asset_contents} ->
                      Logger.info("Assets dir has #{length(asset_contents)} items, first 5: #{Enum.take(asset_contents, 5) |> inspect}")
                    _ -> :ok
                  end
                end
              _ -> :ok
            end
          end
        {:error, reason} ->
          Logger.warning("Could not list temp dir: #{inspect(reason)}")
      end
      move_svgs_to_output(temp_dir, output_dir)
    end
  end

  defp extract_with_system_unzip(zip_path, temp_dir, output_dir) do
    # Extract only assets folder (contains SVGs and metadata.json files)
    {output, exit_code} = System.cmd("unzip", [
      "-q",           # quiet
      "-o",           # overwrite
      zip_path,
      "fluentui-system-icons-main/assets/*",
      "-d", temp_dir
    ], stderr_to_stdout: true)

    if exit_code != 0 do
      {:error, "unzip failed (exit #{exit_code}): #{output}"}
    else
      move_svgs_to_output(temp_dir, output_dir)
    end
  end

  defp extract_with_erlang_zip(zip_path, temp_dir, output_dir) do
    # Erlang :zip.unzip extracts all at once (faster than file-by-file)
    Logger.info("Extracting ZIP to temp directory...")

    case :zip.unzip(String.to_charlist(zip_path), [
      {:cwd, String.to_charlist(temp_dir)}
    ]) do
      {:ok, _files} ->
        Logger.info("ZIP extracted, moving SVG files...")
        move_svgs_to_output(temp_dir, output_dir)

      {:error, reason} ->
        {:error, "Erlang unzip failed: #{inspect(reason)}"}
    end
  end

  defp move_svgs_to_output(temp_dir, output_dir) do
    # Normalize paths to use forward slashes consistently (Windows Path.wildcard issue)
    # Also expand the full path to avoid short names like ONDREJ~1
    normalized_temp_dir = temp_dir |> Path.expand() |> String.replace("\\", "/")
    Logger.info("Normalized temp dir: #{normalized_temp_dir}")

    # Find all SVG files in the extracted content
    # Use simple recursive pattern - the ZIP extracts to fluentui-system-icons-main/assets/*/SVG/
    svg_pattern = "#{normalized_temp_dir}/**/*.svg"
    Logger.info("Searching for SVGs with pattern: #{svg_pattern}")

    all_svgs = Path.wildcard(svg_pattern)
    Logger.info("Path.wildcard found #{length(all_svgs)} total .svg files")

    if length(all_svgs) > 0 do
      Logger.info("Sample SVG path: #{hd(all_svgs)}")
    end

    svg_files =
      all_svgs
      # Filter to only files in SVG directories (handle both Unix / and Windows \ path separators)
      |> Enum.filter(fn path ->
        String.contains?(path, "/SVG/") or String.contains?(path, "\\SVG\\")
      end)

    Logger.info("After /SVG/ filter: #{length(svg_files)} SVG files")

    total = length(svg_files)
    Logger.info("Found #{total} SVG files in #{temp_dir}, moving to output directory...")

    moved =
      svg_files
      |> Enum.with_index(1)
      |> Enum.map(fn {svg_path, idx} ->
        if rem(idx, 5000) == 0 do
          Logger.info("Moving... #{idx}/#{total}")
        end

        filename = Path.basename(svg_path)
        style = extract_style_from_filename(filename)

        if style do
          target_path = Path.join([output_dir, style, filename])
          File.rename(svg_path, target_path)
          :ok
        else
          :skipped
        end
      end)

    ok_count = Enum.count(moved, &(&1 == :ok))
    Logger.info("Extraction complete: #{ok_count} SVGs moved to #{output_dir}")
    {:ok, ok_count}
  end

  defp extract_style_from_filename(filename) do
    # Pattern: ic_fluent_{name}_{size}_{style}.svg
    Enum.find(@valid_styles, fn style ->
      String.ends_with?(filename, "_#{style}.svg")
    end)
  end

  @doc """
  Download all SVG files individually (legacy method).
  Use download_from_zip/0 instead for better performance.
  """
  def download_all do
    # Capture output_dir before spawning tasks to ensure env var is available
    dir = output_dir()
    icons = Repo.all(Icon)
    total = Enum.sum(Enum.map(icons, &length(&1.sizes)))
    Logger.info("Downloading #{total} SVG files for #{length(icons)} icons to #{dir}...")
    Logger.info("TIP: Use download_from_zip/0 for faster bulk downloads")

    results =
      icons
      |> Task.async_stream(&download_icon(&1, dir), max_concurrency: 10, timeout: 60_000)
      |> Enum.to_list()

    successes = Enum.count(results, &match?({:ok, {:ok, _}}, &1))
    Logger.info("Download complete: #{successes}/#{length(icons)} icons downloaded successfully")

    results
  end

  @doc """
  Download all size variants for a single icon.
  Optional dir parameter allows passing the output directory directly.
  """
  def download_icon(icon, dir \\ nil) do
    target_dir = dir || output_dir()

    results =
      Enum.map(icon.sizes, fn size ->
        url = Icon.github_svg_url(icon, size)
        local_path = Path.join([target_dir, icon.style, Icon.svg_filename(icon, size)])

        download_file(url, local_path)
      end)

    if Enum.all?(results, &match?(:ok, &1)) do
      {:ok, icon.name}
    else
      {:error, icon.name, Enum.filter(results, &match?({:error, _}, &1))}
    end
  end

  defp download_file(url, local_path) do
    File.mkdir_p!(Path.dirname(local_path))

    case Req.get(url, retry: :transient, retry_delay: 1000) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(local_path, body)
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("Failed to download #{url}: HTTP #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.warning("Failed to download #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get the output directory path from config.
  Raises if not configured.
  """
  def output_dir do
    Application.get_env(:fluentui_icons, :icons_path) ||
      raise "icons_path not configured - set it in config or via ICONS_PATH env var"
  end

  @doc """
  Get the local file path for an icon SVG.
  """
  def local_svg_path(icon, size) do
    Path.join([output_dir(), icon.style, Icon.svg_filename(icon, size)])
  end

  @doc """
  Check if icons have been downloaded locally.
  """
  def icons_downloaded? do
    case Application.get_env(:fluentui_icons, :icons_path) do
      nil -> false
      dir -> File.dir?(dir) and File.ls!(dir) != []
    end
  end
end
