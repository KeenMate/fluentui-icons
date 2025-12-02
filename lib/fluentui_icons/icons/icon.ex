defmodule FluentuiIcons.Icons.Icon do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icons" do
    field :name, :string
    field :name_lower, :string
    field :style, :string
    field :sizes, {:array, :integer}
    field :ios_identifiers, :map
    field :android_identifiers, :map
    field :search_vector, :any, virtual: true

    timestamps()
  end

  @doc false
  def changeset(icon, attrs) do
    icon
    |> cast(attrs, [:name, :name_lower, :style, :sizes, :ios_identifiers, :android_identifiers])
    |> validate_required([:name, :style, :sizes])
    |> validate_inclusion(:style, ~w(regular filled color light))
    |> unique_constraint([:name, :style])
  end

  @doc """
  Get the configured icons directory path.
  Returns nil if not configured (use GitHub fallback).
  """
  def icons_dir do
    Application.get_env(:fluentui_icons, :icons_path)
  end

  @doc """
  Generate SVG URL for an icon at a specific size.

  Returns local path if icons are configured and file exists, otherwise falls back to GitHub.

  ## Examples

      iex> Icon.svg_url(%Icon{name: "Add", style: "regular"}, 24)
      "/icons/regular/ic_fluent_add_24_regular.svg"  # if downloaded locally
      # or GitHub URL if not configured/downloaded
  """
  def svg_url(%__MODULE__{} = icon, size) do
    case icons_dir() do
      nil ->
        github_svg_url(icon, size)

      dir ->
        local_path = Path.join([dir, icon.style, svg_filename(icon, size)])

        if File.exists?(local_path) do
          "/icons/#{icon.style}/#{svg_filename(icon, size)}"
        else
          github_svg_url(icon, size)
        end
    end
  end

  @doc """
  Generate the GitHub raw URL for an icon SVG.
  """
  def github_svg_url(%__MODULE__{name: name, style: style}, size) do
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")
    encoded_name = URI.encode(name)
    "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/#{encoded_name}/SVG/ic_fluent_#{slug}_#{size}_#{style}.svg"
  end

  @doc """
  Get the local file system path for an icon SVG.
  Returns nil if icons_path is not configured.
  """
  def local_svg_path(%__MODULE__{style: style} = icon, size) do
    case icons_dir() do
      nil -> nil
      dir -> Path.join([dir, style, svg_filename(icon, size)])
    end
  end

  @doc """
  Generate the SVG filename for an icon.
  """
  def svg_filename(%__MODULE__{name: name, style: style}, size) do
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")
    "ic_fluent_#{slug}_#{size}_#{style}.svg"
  end
end
