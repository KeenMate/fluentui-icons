defmodule FluentuiIconsWeb.API.IconController do
  use FluentuiIconsWeb, :controller

  alias FluentuiIcons.Icons
  alias FluentuiIcons.Icons.Icon

  @doc """
  Search for icons.

  ## Query Parameters
    * `q` - Search query (required)
    * `size` - Filter by size (optional, e.g., "24", "48")
    * `style` - Filter by style (optional, e.g., "regular", "filled")
    * `limit` - Max results (optional, default: 50, max: 100)

  ## Examples

      GET /api/icons/search?q=pen
      GET /api/icons/search?q=pen&size=48
      GET /api/icons/search?q=calendar&style=regular&limit=20
  """
  def search(conn, params) do
    query = params["q"] || ""
    size = parse_size(params["size"])
    style = params["style"]
    limit = parse_limit(params["limit"])

    icons = Icons.search(query, size: size, style: style, limit: limit)

    json(conn, %{
      query: query,
      count: length(icons),
      results: Enum.map(icons, &format_icon/1)
    })
  end

  defp parse_size(nil), do: nil
  defp parse_size(""), do: nil

  defp parse_size(s) do
    case Integer.parse(s) do
      {size, _} -> size
      :error -> nil
    end
  end

  defp parse_limit(nil), do: 50
  defp parse_limit(""), do: 50

  defp parse_limit(s) do
    case Integer.parse(s) do
      {limit, _} -> min(limit, 100)
      :error -> 50
    end
  end

  defp format_icon(icon) do
    %{
      id: icon.id,
      name: icon.name,
      style: icon.style,
      sizes: icon.sizes,
      ios: icon.ios_identifiers,
      android: icon.android_identifiers,
      svg_url: Icon.svg_url(icon, default_size(icon.sizes))
    }
  end

  defp default_size(sizes) do
    # Prefer 24px if available, otherwise use the first size
    if 24 in sizes, do: 24, else: hd(sizes)
  end
end
