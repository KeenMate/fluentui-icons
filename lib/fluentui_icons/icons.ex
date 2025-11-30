defmodule FluentuiIcons.Icons do
  @moduledoc """
  The Icons context - handles searching and querying FluentUI icons.
  """

  import Ecto.Query, warn: false
  alias FluentuiIcons.Repo
  alias FluentuiIcons.Icons.Icon

  @doc """
  Search for icons by name with optional filters.

  ## Options
    * `:sizes` - Filter by sizes (list of integers) - matches icons having ANY of the sizes
    * `:styles` - Filter by styles (list of strings) - matches icons having ANY of the styles
    * `:limit` - Maximum number of results (default: 50)
    * `:offset` - Number of results to skip (default: 0)

  ## Examples

      iex> Icons.search("pen")
      [%Icon{name: "Pen", ...}, ...]

      iex> Icons.search("pen", sizes: [24, 48], styles: ["regular", "filled"], limit: 10)
      [%Icon{name: "Pen", style: "regular", ...}]
  """
  def search(query, opts \\ []) do
    sizes = opts[:sizes] || []
    styles = opts[:styles] || []
    limit = opts[:limit] || 50
    offset_val = opts[:offset] || 0

    Icon
    |> apply_text_search(query)
    |> apply_sizes_filter(sizes)
    |> apply_styles_filter(styles)
    |> order_by_relevance(query)
    |> limit(^limit)
    |> offset(^offset_val)
    |> Repo.all()
  end

  @doc """
  Count icons matching search criteria (for pagination).
  """
  def search_count(query, opts \\ []) do
    sizes = opts[:sizes] || []
    styles = opts[:styles] || []

    Icon
    |> apply_text_search(query)
    |> apply_sizes_filter(sizes)
    |> apply_styles_filter(styles)
    |> Repo.aggregate(:count)
  end

  defp apply_text_search(q, nil), do: q
  defp apply_text_search(q, ""), do: q

  defp apply_text_search(q, term) do
    # Lowercase ONCE at query time - all DB columns are pre-lowercased
    term_lower = String.downcase(term)
    search_pattern = "%#{term_lower}%"
    prefix_query = sanitize_tsquery(term)

    where(
      q,
      [i],
      # Full-text search with prefix (pen finds pencil)
      fragment("search_vector @@ to_tsquery('english', ?)", ^prefix_query) or
      # Trigram similarity for typos (using lowercase column)
      fragment("? % ?", i.name_lower, ^term_lower) or
      # Substring match on lowercase column
      fragment("? LIKE ?", i.name_lower, ^search_pattern) or
      # Synonym matches (all lowercase in DB) - use raw SQL EXISTS
      fragment(
        """
        EXISTS(
          SELECT 1 FROM icon_synonyms s
          WHERE s.icon_name_lower = ? AND s.icon_style = ?
          AND (s.synonym = ? OR s.synonym LIKE ? OR s.synonym % ?)
        )
        """,
        i.name_lower,
        i.style,
        ^term_lower,
        ^search_pattern,
        ^term_lower
      )
    )
  end

  defp sanitize_tsquery(term) do
    term
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.trim()
    |> String.replace(~r/\s+/, " & ")
    |> Kernel.<>(":*")
  end

  defp apply_sizes_filter(q, []), do: q

  defp apply_sizes_filter(q, sizes) when is_list(sizes) do
    # Match icons that have ANY of the selected sizes
    where(q, [i], fragment("? && ?", i.sizes, ^sizes))
  end

  defp apply_styles_filter(q, []), do: q

  defp apply_styles_filter(q, styles) when is_list(styles) do
    # Match icons that have ANY of the selected styles
    where(q, [i], i.style in ^styles)
  end

  defp order_by_relevance(q, nil), do: order_by(q, [i], i.name)
  defp order_by_relevance(q, ""), do: order_by(q, [i], i.name)

  defp order_by_relevance(q, term) do
    # Weighted ranking: ts_rank (2x) + trigram similarity (1x) + synonym boost (1.5)
    prefix_query = sanitize_tsquery(term)
    term_lower = String.downcase(term)

    order_by(q, [i], [
      desc:
        fragment(
          """
          COALESCE(ts_rank(search_vector, to_tsquery('english', ?)), 0) * 2.0 +
          similarity(?, ?) +
          CASE WHEN EXISTS(
            SELECT 1 FROM icon_synonyms s
            WHERE s.icon_name_lower = ? AND s.icon_style = ? AND s.synonym = ?
          ) THEN 1.5 ELSE 0 END
          """,
          ^prefix_query,
          i.name_lower,
          ^term_lower,
          i.name_lower,
          i.style,
          ^term_lower
        ),
      asc: i.name
    ])
  end

  @doc """
  Returns the total count of icons in the database.
  """
  def count do
    Repo.aggregate(Icon, :count)
  end

  @doc """
  Get a single icon by name and style.
  """
  def get_by_name(name, style) do
    Repo.get_by(Icon, name: name, style: style)
  end

  @doc """
  Get a single icon by ID.
  """
  def get_icon!(id), do: Repo.get!(Icon, id)

  @doc """
  List all icons with optional pagination.
  """
  def list_icons(opts \\ []) do
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0

    Icon
    |> order_by([i], i.name)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end
end
