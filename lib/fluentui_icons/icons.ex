defmodule FluentuiIcons.Icons do
  @moduledoc """
  The Icons context - handles searching and querying FluentUI icons.
  """

  import Ecto.Query, warn: false
  alias FluentuiIcons.Repo
  alias FluentuiIcons.Icons.{Icon, IconMetric, IconMetricsCube}

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

  # ---- Metrics Tracking ----

  @doc """
  Track a copy or download action for an icon.

  ## Examples

      iex> Icons.track_action(icon_id, "copy", platform: "svelte", size: 24)
      {:ok, %IconMetric{}}
  """
  def track_action(icon_id, action, opts \\ []) do
    %IconMetric{}
    |> IconMetric.changeset(%{
      icon_id: icon_id,
      action: action,
      size: opts[:size],
      platform: opts[:platform]
    })
    |> Repo.insert()
  end

  @doc """
  Get the most popular icons by copy/download count.

  ## Options
    * `:action` - Filter by "copy" or "download" (default: both)
    * `:limit` - Maximum results (default: 20)
    * `:since` - DateTime to filter from (default: all time)
  """
  def popular_icons(opts \\ []) do
    action = opts[:action]
    limit = opts[:limit] || 20
    since = opts[:since]

    query =
      from m in IconMetric,
        join: i in Icon, on: m.icon_id == i.id,
        group_by: [i.id, i.name, i.style],
        select: %{
          icon_id: i.id,
          name: i.name,
          style: i.style,
          count: count(m.id)
        },
        order_by: [desc: count(m.id)],
        limit: ^limit

    query
    |> maybe_filter_action(action)
    |> maybe_filter_since(since)
    |> Repo.all()
  end

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, action) do
    where(query, [m], m.action == ^action)
  end

  defp maybe_filter_since(query, nil), do: query
  defp maybe_filter_since(query, since) do
    where(query, [m], m.inserted_at >= ^since)
  end

  @doc """
  Get metrics summary for a specific icon.
  """
  def icon_metrics(icon_id) do
    from(m in IconMetric,
      where: m.icon_id == ^icon_id,
      group_by: m.action,
      select: {m.action, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ---- Metrics Cube (Pre-aggregated) ----

  @doc """
  Refresh the metrics cube with current aggregations.
  Run this nightly via scheduler.
  """
  def refresh_metrics_cube do
    require Logger
    Logger.info("Refreshing metrics cube...")

    now = DateTime.utc_now()
    seven_days_ago = DateTime.add(now, -7, :day)
    thirty_days_ago = DateTime.add(now, -30, :day)

    Repo.transaction(fn ->
      # Clear existing cube data
      Repo.delete_all(IconMetricsCube)

      # Compute and insert for each period
      for {period, since} <- [{"7d", seven_days_ago}, {"30d", thirty_days_ago}, {"all", nil}] do
        aggregations = compute_aggregations(since)
        count = length(aggregations)

        aggregations
        |> Enum.map(&Map.put(&1, :period, period))
        |> Enum.chunk_every(500)
        |> Enum.each(&Repo.insert_all(IconMetricsCube, &1))

        Logger.info("Inserted #{count} cube entries for period #{period}")
      end
    end)

    Logger.info("Metrics cube refresh complete")
    :ok
  end

  defp compute_aggregations(nil) do
    # All time
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(m in IconMetric,
      group_by: [m.icon_id, m.action],
      select: %{
        icon_id: m.icon_id,
        action: m.action,
        count: count(m.id)
      }
    )
    |> Repo.all()
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
  end

  defp compute_aggregations(since) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(m in IconMetric,
      where: m.inserted_at >= ^since,
      group_by: [m.icon_id, m.action],
      select: %{
        icon_id: m.icon_id,
        action: m.action,
        count: count(m.id)
      }
    )
    |> Repo.all()
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
  end

  @doc """
  Get popular icons from the cube (fast).

  ## Options
    * `:period` - Time period: "7d", "30d", or "all" (default: "all")
    * `:action` - Filter by "copy" or "download" (default: both)
    * `:limit` - Maximum results (default: 20)

  ## Examples

      iex> Icons.popular_icons_from_cube(period: "7d", action: "download", limit: 10)
      [%{icon_id: 1, name: "Add", style: "regular", count: 150, action: "download"}, ...]
  """
  def popular_icons_from_cube(opts \\ []) do
    period = opts[:period] || "all"
    action = opts[:action]
    limit = opts[:limit] || 20

    query =
      from c in IconMetricsCube,
        join: i in Icon, on: c.icon_id == i.id,
        where: c.period == ^period,
        order_by: [desc: c.count],
        limit: ^limit,
        select: %{
          icon_id: i.id,
          name: i.name,
          style: i.style,
          count: c.count,
          action: c.action
        }

    query
    |> maybe_filter_cube_action(action)
    |> Repo.all()
  end

  defp maybe_filter_cube_action(query, nil), do: query
  defp maybe_filter_cube_action(query, action), do: where(query, [c], c.action == ^action)
end
