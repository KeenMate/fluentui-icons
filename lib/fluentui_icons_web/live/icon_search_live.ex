defmodule FluentuiIconsWeb.IconSearchLive do
  use FluentuiIconsWeb, :live_view

  alias FluentuiIcons.Icons
  alias FluentuiIcons.Icons.Icon
  alias FluentuiIcons.Sync.SyncRun
  alias Phoenix.LiveView.JS

  import FluentuiIconsWeb.Components.PlatformIcons

  @per_page 30

  @impl true
  def mount(_params, _session, socket) do
    # Get preferences from connect params (passed from JS localStorage)
    # get_connect_params returns nil during static render, so we use defaults
    connect_params = get_connect_params(socket) || %{}
    view_mode = connect_params["view_mode"] || "grid"
    platform_prefs = connect_params["platform_prefs"] || %{}
    platform_prefs = atomize_keys(platform_prefs)
    default_prefs = %{ios: true, android: true, react: true, svelte: true, filename: true}
    platform_prefs = Map.merge(default_prefs, platform_prefs)

    last_sync = SyncRun.last_successful()

    {:ok,
     socket
     |> assign(icon_count: Icons.count())
     |> assign(platform_prefs: platform_prefs)
     |> assign(view_mode: view_mode)
     |> assign(last_sync_at: last_sync && last_sync.completed_at)
     |> assign(discrepancy_count: last_sync && last_sync.discrepancy_count || 0)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""
    styles = parse_list(params["styles"])
    sizes = parse_sizes(params["sizes"])
    page = parse_page(params["page"])

    assigns = %{selected_styles: styles, selected_sizes: sizes, page: page}
    icons = search_icons(query, assigns)
    total_count = get_total_count(query, assigns)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     assign(socket,
       query: query,
       selected_styles: styles,
       selected_sizes: sizes,
       page: page,
       icons: icons,
       total_count: total_count,
       total_pages: total_pages,
       selected_icon: nil
     )}
  end

  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1
  defp parse_page(page_str) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_list(nil), do: []
  defp parse_list(""), do: []
  defp parse_list(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_sizes(nil), do: []
  defp parse_sizes(""), do: []
  defp parse_sizes(sizes_str) do
    sizes_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, q: query, page: 1))}
  end

  def handle_event("toggle_size", %{"size" => size}, socket) do
    size = String.to_integer(size)
    sizes = socket.assigns.selected_sizes
    new_sizes = if size in sizes, do: List.delete(sizes, size), else: [size | sizes]
    {:noreply, push_patch(socket, to: build_path(socket, sizes: new_sizes, page: 1))}
  end

  def handle_event("toggle_style", %{"style" => style}, socket) do
    styles = socket.assigns.selected_styles
    new_styles = if style in styles, do: List.delete(styles, style), else: [style | styles]
    {:noreply, push_patch(socket, to: build_path(socket, styles: new_styles, page: 1))}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, styles: [], sizes: [], page: 1))}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: String.to_integer(page)))}
  end

  def handle_event("select_icon", %{"id" => id}, socket) do
    icon = Enum.find(socket.assigns.icons, &(to_string(&1.id) == id))
    # Fetch metrics for this icon (from raw table, fast enough for single icon)
    metrics = if icon, do: Icons.icon_metrics(icon.id), else: %{}
    {:noreply, assign(socket, selected_icon: icon, icon_metrics: metrics)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_icon: nil)}
  end

  def handle_event("toggle_platform", %{"platform" => platform}, socket) do
    prefs = socket.assigns.platform_prefs
    new_prefs = Map.update!(prefs, String.to_existing_atom(platform), &(!&1))

    socket =
      socket
      |> assign(:platform_prefs, new_prefs)
      |> push_event("save_platform_prefs", new_prefs)

    {:noreply, socket}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    socket =
      socket
      |> assign(view_mode: mode)
      |> push_event("save_view_mode", %{mode: mode})

    {:noreply, socket}
  end

  def handle_event("track_download", %{"icon-id" => icon_id, "size" => size}, socket) do
    # Track download asynchronously (don't block the UI)
    Task.start(fn ->
      Icons.track_action(String.to_integer(icon_id), "download", size: String.to_integer(size))
    end)
    {:noreply, socket}
  end

  def handle_event("track_copy", %{"icon-id" => icon_id, "platform" => platform} = params, socket) do
    # Track copy asynchronously
    size = params["size"]
    Task.start(fn ->
      opts = [platform: platform]
      opts = if size, do: [{:size, String.to_integer(size)} | opts], else: opts
      Icons.track_action(String.to_integer(icon_id), "copy", opts)
    end)
    {:noreply, socket}
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
  end

  defp build_path(socket, overrides) do
    query = Keyword.get(overrides, :q, socket.assigns.query)
    styles = Keyword.get(overrides, :styles, socket.assigns.selected_styles)
    sizes = Keyword.get(overrides, :sizes, socket.assigns.selected_sizes)
    page = Keyword.get(overrides, :page, socket.assigns.page)

    params =
      []
      |> maybe_add_param("q", query, "")
      |> maybe_add_list("styles", styles)
      |> maybe_add_list("sizes", Enum.map(sizes, &to_string/1))
      |> maybe_add_param("page", page, 1)

    case params do
      [] -> "/"
      _ -> "/?" <> URI.encode_query(params)
    end
  end

  defp maybe_add_param(params, _key, value, default) when value == default, do: params
  defp maybe_add_param(params, key, value, _default), do: [{key, value} | params]

  defp maybe_add_list(params, _key, []), do: params
  defp maybe_add_list(params, key, list) do
    [{key, Enum.join(Enum.sort(list), ",")} | params]
  end

  defp search_icons(query, assigns) do
    offset = (assigns.page - 1) * @per_page
    opts = [limit: @per_page, offset: offset]

    opts =
      case assigns.selected_styles do
        [] -> opts
        styles -> [{:styles, styles} | opts]
      end

    opts =
      case assigns.selected_sizes do
        [] -> opts
        sizes -> [{:sizes, sizes} | opts]
      end

    Icons.search(query, opts)
  end

  defp get_total_count(query, assigns) do
    opts = []

    opts =
      case assigns.selected_styles do
        [] -> opts
        styles -> [{:styles, styles} | opts]
      end

    opts =
      case assigns.selected_sizes do
        [] -> opts
        sizes -> [{:sizes, sizes} | opts]
      end

    Icons.search_count(query, opts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Hidden element for metrics tracking from JS -->
      <div id="metrics-tracker" phx-hook="MetricsTracker" class="hidden"></div>
      <div class="max-w-7xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">FluentUI Icon Search</h1>
          <p class="text-gray-600 mt-1">Search <%= @icon_count %> icons from Microsoft's FluentUI System Icons</p>
        </div>

        <!-- Search Bar -->
        <form phx-change="search" phx-submit="search" class="mb-6">
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search icons (e.g., 'pen', 'calendar', 'add')..."
              phx-debounce="300"
              class="w-full pl-10 pr-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-gray-900"
              autofocus
            />
          </div>
        </form>

        <!-- Filters -->
        <div class="flex flex-wrap gap-6 mb-6 items-center">
          <!-- Style Filter -->
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-gray-700">Styles:</span>
            <%= for style <- ["regular", "filled", "color", "light"] do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_style"
                  phx-value-style={style}
                  checked={style in @selected_styles}
                  class="w-5 h-5 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                />
                <span class="text-base text-gray-600 capitalize"><%= style %></span>
              </label>
            <% end %>
          </div>

          <!-- Size Filters -->
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-gray-700">Sizes:</span>
            <%= for size <- [16, 20, 24, 28, 32, 48] do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_size"
                  phx-value-size={size}
                  checked={size in @selected_sizes}
                  class="w-5 h-5 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                />
                <span class="text-base text-gray-600"><%= size %></span>
              </label>
            <% end %>
          </div>

          <!-- Clear Filters -->
          <%= if @selected_styles != [] || @selected_sizes != [] do %>
            <button
              phx-click="clear_filters"
              class="text-base text-blue-600 hover:text-blue-800"
            >
              Clear filters
            </button>
          <% end %>
        </div>

        <!-- Active Filters Display -->
        <%= if @selected_styles != [] || @selected_sizes != [] do %>
          <div class="flex flex-wrap gap-2 mb-4 items-center">
            <span class="text-sm text-gray-500">Active filters:</span>
            <%= for style <- Enum.sort(@selected_styles) do %>
              <button
                type="button"
                phx-click="toggle_style"
                phx-value-style={style}
                class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-sm bg-blue-600 text-white hover:bg-blue-700"
              >
                <%= style %>
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
            <%= for size <- Enum.sort(@selected_sizes) do %>
              <button
                type="button"
                phx-click="toggle_size"
                phx-value-size={size}
                class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-sm bg-blue-600 text-white hover:bg-blue-700"
              >
                <%= size %>px
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
          </div>
        <% end %>

        <!-- Results Count, View Toggle & Pager -->
        <div class="flex justify-between items-center mb-4">
          <div class="text-sm text-gray-600">
            Showing <%= (@page - 1) * 30 + 1 %>-<%= min(@page * 30, @total_count) %> of <%= @total_count %> icons
          </div>
          <div class="flex items-center gap-4">
            <!-- View Toggle - CSS controls active state based on data-view-mode -->
            <div class="flex items-center gap-1 bg-gray-100 rounded-lg p-1" id="view-mode" phx-hook="ViewMode">
              <button
                phx-click="toggle_view"
                phx-value-mode="grid"
                class="btn-grid px-3 py-1.5 rounded text-sm flex items-center gap-1.5"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
                Grid
              </button>
              <button
                phx-click="toggle_view"
                phx-value-mode="list"
                class="btn-list px-3 py-1.5 rounded text-sm flex items-center gap-1.5"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                </svg>
                List
              </button>
            </div>
            <.pager current_page={@page} total_pages={@total_pages} />
          </div>
        </div>

        <!-- Icon Display (Grid or List) - Both rendered, CSS controls visibility -->
        <div id="icon-display" phx-hook="IconColorFilter">
          <div class="view-grid">
            <.icon_grid icons={@icons} selected_styles={@selected_styles} selected_sizes={@selected_sizes} platform_prefs={@platform_prefs} />
          </div>
          <div class="view-list">
            <.icon_list icons={@icons} platform_prefs={@platform_prefs} />
          </div>
        </div>

        <!-- Bottom Pager -->
        <%= if @total_pages > 1 do %>
          <div class="flex justify-end mt-6">
            <.pager current_page={@page} total_pages={@total_pages} />
          </div>
        <% end %>

        <!-- Empty State -->
        <%= if @query != "" and @icons == [] do %>
          <div class="text-center py-16">
            <svg class="h-16 w-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-gray-500">No icons found for "<%= @query %>"</p>
            <p class="text-sm text-gray-400 mt-1">Try a different search term or adjust your filters</p>
          </div>
        <% end %>

        <!-- API Info -->
        <div class="mt-12 p-4 bg-gray-100 rounded-lg">
          <h2 class="font-semibold text-gray-900 mb-2">API Access</h2>
          <p class="text-sm text-gray-600 mb-2">
            Use the JSON API to search icons programmatically:
          </p>
          <code class="text-sm bg-white px-2 py-1 rounded border">
            GET /api/icons/search?q=pen&size=48
          </code>
        </div>

        <!-- Footer -->
        <footer class="mt-12 py-6 border-t border-gray-200 text-sm text-gray-500">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-2">
            <div>
              Made by <a href="https://keenmate.com" rel="noreferrer" referrerpolicy="origin" class="text-blue-600 hover:underline">Keenmate</a>
            </div>
            <%= if @last_sync_at do %>
              <div class="text-xs text-gray-400 flex items-center gap-2">
                <span>Last synced: <%= format_sync_time(@last_sync_at) %></span>
                <%= if @discrepancy_count > 0 do %>
                  <a href="/sync/discrepancies" class="text-orange-500 hover:text-orange-600 hover:underline">
                    (<%= @discrepancy_count %> discrepancies)
                  </a>
                <% end %>
              </div>
            <% end %>
          </div>
        </footer>
      </div>

      <!-- Icon Detail Modal -->
      <%= if @selected_icon do %>
        <.icon_modal icon={@selected_icon} platform_prefs={@platform_prefs} metrics={@icon_metrics} />
      <% end %>
    </div>
    """
  end

  defp icon_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close_modal"></div>

      <!-- Modal -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class="relative bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
          <!-- Close button -->
          <button
            phx-click="close_modal"
            class="absolute top-4 right-4 text-gray-400 hover:text-gray-600 z-10"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <div class="p-6">
            <!-- Header -->
            <div class="text-center mb-6">
              <h2 class="text-2xl font-bold text-gray-900" id="modal-title"><%= @icon.name %></h2>
              <span class="inline-block mt-1 px-2 py-0.5 rounded text-sm bg-gray-100 text-gray-600 capitalize"><%= @icon.style %></span>

              <!-- Stats -->
              <% copies = Map.get(@metrics, "copy", 0) %>
              <% downloads = Map.get(@metrics, "download", 0) %>
              <% total = copies + downloads %>
              <%= if total > 0 do %>
                <div class="flex justify-center gap-3 mt-3">
                  <div class="px-3 py-1.5 bg-blue-50 rounded-lg text-center">
                    <div class="text-lg font-semibold text-blue-600"><%= format_number(copies) %></div>
                    <div class="text-xs text-blue-500">copies</div>
                  </div>
                  <div class="px-3 py-1.5 bg-green-50 rounded-lg text-center">
                    <div class="text-lg font-semibold text-green-600"><%= format_number(downloads) %></div>
                    <div class="text-xs text-green-500">downloads</div>
                  </div>
                  <div class="px-3 py-1.5 bg-gray-100 rounded-lg text-center">
                    <div class="text-lg font-semibold text-gray-700"><%= format_number(total) %></div>
                    <div class="text-xs text-gray-500">total</div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Color Picker -->
            <div class="mb-4 flex items-center gap-3" id={"color-picker-#{@icon.id}"} phx-hook="ColorPicker"
                 data-update-trigger={:erlang.phash2(@platform_prefs)}>
              <label class="text-sm font-medium text-gray-700">Preview Color:</label>
              <input type="color" value="#212121"
                     class="color-input w-10 h-10 rounded cursor-pointer border border-gray-300" />
              <input type="text" value="#212121"
                     class="color-text w-24 px-2 py-1 text-sm font-mono border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                     maxlength="7" placeholder="#000000" />
            </div>

            <!-- Icon Sizes Preview with Download -->
            <div class="mb-6">
              <h3 class="text-sm font-medium text-gray-700 mb-3">Available Sizes</h3>
              <div class="flex flex-wrap gap-4 justify-center items-end"
                   id={"icon-preview-#{@icon.id}"}
                   phx-hook="InlineSvg"
                   data-color="#212121"
                   data-urls={Jason.encode!(Enum.map(@icon.sizes, &Icon.svg_url(@icon, &1)))}>
                <%= for size <- @icon.sizes do %>
                  <div class="flex flex-col items-center">
                    <div class="svg-container bg-gray-50 rounded-lg p-3 border border-gray-200 flex items-center justify-center"
                         data-size={size}
                         style={"width: #{min(size + 24, 96)}px; height: #{min(size + 24, 96)}px;"}>
                      <!-- SVG loaded by JavaScript -->
                    </div>
                    <span class="text-xs text-gray-500 mt-1"><%= size %>px</span>
                    <a href={Icon.svg_url(@icon, size)}
                       download={Icon.svg_filename(@icon, size)}
                       phx-click="track_download"
                       phx-value-icon-id={@icon.id}
                       phx-value-size={size}
                       title="Download SVG"
                       class="mt-1 p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md transition-colors">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                    </a>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Platform Identifiers -->
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-medium text-gray-700">Platform Identifiers</h3>
              </div>

              <!-- Platform Toggle Checkboxes -->
              <div class="flex flex-wrap gap-4 pb-4 border-b border-gray-200" id="platform-prefs" phx-hook="PlatformPrefs">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.ios}
                    phx-click="toggle_platform"
                    phx-value-platform="ios"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <.platform_icon name="ios" class="w-4 h-4 text-gray-600" />
                  <span class="text-sm text-gray-600">iOS</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.android}
                    phx-click="toggle_platform"
                    phx-value-platform="android"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <.platform_icon name="android" class="w-4 h-4 text-gray-600" />
                  <span class="text-sm text-gray-600">Android</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.react}
                    phx-click="toggle_platform"
                    phx-value-platform="react"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <.platform_icon name="react" class="w-4 h-4 text-gray-600" />
                  <span class="text-sm text-gray-600">React</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.svelte}
                    phx-click="toggle_platform"
                    phx-value-platform="svelte"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <.platform_icon name="svelte" class="w-4 h-4 text-gray-600" />
                  <span class="text-sm text-gray-600">Svelte</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.filename}
                    phx-click="toggle_platform"
                    phx-value-platform="filename"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <.platform_icon name="filename" class="w-4 h-4 text-gray-600" />
                  <span class="text-sm text-gray-600">Filename</span>
                </label>
              </div>

              <!-- iOS -->
              <%= if @platform_prefs.ios do %>
                <div class="bg-gray-50 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-600 flex items-center gap-1.5">
                      <.platform_icon name="ios" class="w-4 h-4" />
                      iOS (Swift)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for {size, id} <- @icon.ios_identifiers do %>
                      <div class="flex items-center justify-between bg-white rounded px-3 py-2 border border-gray-200">
                        <code class="text-sm text-blue-600"><%= id %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#ios-#{@icon.id}-#{size}")}
                          class="text-xs text-gray-500 hover:text-gray-700 px-2 py-1 rounded hover:bg-gray-100"
                        >Copy</button>
                        <span id={"ios-#{@icon.id}-#{size}"} class="hidden"><%= id %></span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Android -->
              <%= if @platform_prefs.android do %>
                <div class="bg-gray-50 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-600 flex items-center gap-1.5">
                      <.platform_icon name="android" class="w-4 h-4" />
                      Android (Kotlin/Java)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for {size, id} <- @icon.android_identifiers do %>
                      <div class="flex items-center justify-between bg-white rounded px-3 py-2 border border-gray-200">
                        <code class="text-sm text-green-600"><%= id %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#android-#{@icon.id}-#{size}")}
                          class="text-xs text-gray-500 hover:text-gray-700 px-2 py-1 rounded hover:bg-gray-100"
                        >Copy</button>
                        <span id={"android-#{@icon.id}-#{size}"} class="hidden"><%= id %></span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- React -->
              <%= if @platform_prefs.react do %>
                <div class="bg-gray-50 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-600 flex items-center gap-1.5">
                      <.platform_icon name="react" class="w-4 h-4" />
                      React (@fluentui/react-icons)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for size <- @icon.sizes do %>
                      <div class="flex items-center justify-between bg-white rounded px-3 py-2 border border-gray-200">
                        <code id={"react-#{@icon.id}-#{size}"} class="text-sm text-purple-600"><%= react_identifier(@icon, size) %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#react-#{@icon.id}-#{size}")}
                          class="text-xs text-gray-500 hover:text-gray-700 px-2 py-1 rounded hover:bg-gray-100"
                        >Copy</button>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Svelte -->
              <%= if @platform_prefs.svelte do %>
                <div class="bg-gray-50 rounded-lg p-4" id={"svelte-section-#{@icon.id}"} phx-hook="SvelteColor"
                     data-name={@icon.name |> String.downcase() |> String.replace(" ", "_")}
                     data-style={@icon.style}
                     data-sizes={Jason.encode!(@icon.sizes)}>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-600 flex items-center gap-1.5">
                      <.platform_icon name="svelte" class="w-4 h-4" />
                      Svelte (svelte-fluentui)
                    </span>
                    <label class="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer">
                      <input type="checkbox" class="svelte-include-color w-3.5 h-3.5 rounded border-gray-300" />
                      Include color
                    </label>
                  </div>
                  <div class="space-y-1 svelte-code-list">
                    <%= for size <- @icon.sizes do %>
                      <div class="flex items-center justify-between bg-white rounded px-3 py-2 border border-gray-200">
                        <code id={"svelte-#{@icon.id}-#{size}"} class="text-sm text-orange-600" data-size={size}><%= svelte_identifier(@icon, size) %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#svelte-#{@icon.id}-#{size}")}
                          class="text-xs text-gray-500 hover:text-gray-700 px-2 py-1 rounded hover:bg-gray-100"
                        >Copy</button>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Filename -->
              <%= if @platform_prefs.filename do %>
                <div class="bg-gray-50 rounded-lg p-4" id={"filename-section-#{@icon.id}"} phx-hook="FilenameTemplate"
                     data-name={@icon.name} data-style={@icon.style} data-sizes={Jason.encode!(@icon.sizes)}>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-600 flex items-center gap-1.5">
                      <.platform_icon name="filename" class="w-4 h-4" />
                      Filename (local copy)
                    </span>
                  </div>
                  <div class="mb-1 text-xs text-gray-500">
                    <span class="font-medium">Placeholders:</span>
                    <code class="bg-gray-200 px-1 rounded">{filename}</code>
                    <code class="bg-gray-200 px-1 rounded">{name}</code>
                    <code class="bg-gray-200 px-1 rounded">{name_snake}</code>
                    <code class="bg-gray-200 px-1 rounded">{name_pascal}</code>
                    <code class="bg-gray-200 px-1 rounded">{name_kebab}</code>
                    <code class="bg-gray-200 px-1 rounded">{size}</code>
                    <code class="bg-gray-200 px-1 rounded">{style}</code>
                  </div>
                  <div class="mb-3">
                    <input type="text" id={"filename-template-input-#{@icon.id}"}
                           class="w-full px-3 py-2 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                           placeholder="/my/assets/{filename}" />
                  </div>
                  <div id={"filename-results-#{@icon.id}"} class="space-y-1">
                    <!-- Populated by JavaScript -->
                  </div>
                </div>
              <% end %>
            </div>

            <!-- SVG URLs -->
            <div class="mt-6">
              <h3 class="text-sm font-medium text-gray-700 mb-2">SVG URLs</h3>
              <div class="space-y-1">
                <%= for size <- @icon.sizes do %>
                  <div class="flex items-center gap-2 text-xs">
                    <span class="text-gray-500 w-10"><%= size %>px:</span>
                    <a
                      href={Icon.svg_url(@icon, size)}
                      target="_blank"
                      class="text-blue-600 hover:underline truncate flex-1"
                    ><%= Icon.svg_url(@icon, size) %></a>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp pager(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <button
        :if={@current_page > 1}
        phx-click="change_page"
        phx-value-page={@current_page - 1}
        class="px-3 py-1 rounded bg-gray-200 hover:bg-gray-300 text-sm"
      >Previous</button>
      <button
        :if={@current_page <= 1}
        disabled
        class="px-3 py-1 rounded bg-gray-100 text-gray-400 text-sm cursor-not-allowed"
      >Previous</button>

      <span class="text-sm text-gray-600">
        Page <%= @current_page %> of <%= @total_pages %>
      </span>

      <button
        :if={@current_page < @total_pages}
        phx-click="change_page"
        phx-value-page={@current_page + 1}
        class="px-3 py-1 rounded bg-gray-200 hover:bg-gray-300 text-sm"
      >Next</button>
      <button
        :if={@current_page >= @total_pages}
        disabled
        class="px-3 py-1 rounded bg-gray-100 text-gray-400 text-sm cursor-not-allowed"
      >Next</button>
    </div>
    """
  end

  defp icon_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      <%= for icon <- @icons do %>
        <div
          phx-click="select_icon"
          phx-value-id={icon.id}
          class="bg-white rounded-lg border border-gray-200 p-4 hover:shadow-lg hover:border-blue-500 transition cursor-pointer group"
        >
          <!-- Icon Preview -->
          <div class="w-12 h-12 mx-auto mb-3 flex items-center justify-center">
            <span class="inline-svg-icon inline-flex items-center justify-center w-8 h-8" data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
          </div>

          <!-- Icon Name -->
          <div class="text-sm font-medium text-gray-900 text-center truncate" title={icon.name}>
            <%= icon.name %>
          </div>

          <!-- Style & Sizes (clickable tags) -->
          <div class="text-xs text-center mt-1 flex flex-wrap justify-center gap-1">
            <button
              type="button"
              phx-click="toggle_style"
              phx-value-style={icon.style}
              class={"px-1.5 py-0.5 rounded text-xs #{if icon.style in @selected_styles, do: "bg-blue-600 text-white", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}
            ><%= icon.style %></button>
            <%= for size <- icon.sizes do %>
              <button
                type="button"
                phx-click="toggle_size"
                phx-value-size={size}
                class={"px-1.5 py-0.5 rounded text-xs #{if size in @selected_sizes, do: "bg-blue-600 text-white", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}
              ><%= size %>px</button>
            <% end %>
          </div>

          <!-- Identifiers (shown on hover) - shows first 2 preferred platforms -->
          <div class="mt-3 opacity-0 group-hover:opacity-100 transition-opacity space-y-1 text-xs">
            <%= for platform <- preferred_platforms(@platform_prefs, 2) do %>
              <div class="bg-gray-50 rounded px-2 py-1 flex items-center gap-1 group/copy">
                <.platform_icon name={to_string(platform)} class="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
                <span class="truncate flex-1" title={get_platform_id(icon, platform)}>
                  <code class={platform_color(platform)}><%= get_platform_id(icon, platform) %></code>
                </span>
                <button
                  type="button"
                  phx-click={JS.dispatch("phx:copy_text", detail: %{text: get_platform_id(icon, platform), icon_id: icon.id, platform: platform})}
                  class="opacity-0 group-hover/copy:opacity-100 text-gray-400 hover:text-gray-600 p-0.5"
                  title="Copy"
                >
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp icon_list(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-gray-100 border-b-2 border-gray-300">
            <tr>
              <th class="px-4 py-4 text-left font-semibold text-gray-700 text-base">Icon</th>
              <th class="px-4 py-4 text-left font-semibold text-gray-700 text-base">Name</th>
              <th class="px-4 py-4 text-center font-semibold text-gray-700 text-base">Style</th>
              <%= for size <- [16, 20, 24, 28, 32, 48] do %>
                <th class="px-3 py-4 text-center font-semibold text-gray-700 text-sm"><%= size %></th>
              <% end %>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for icon <- @icons do %>
              <tr
                phx-click="select_icon"
                phx-value-id={icon.id}
                class="hover:bg-blue-50 cursor-pointer transition-colors group"
              >
                <td class="px-4 py-3">
                  <span class="inline-svg-icon inline-flex items-center justify-center w-6 h-6" data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
                </td>
                <td class="px-4 py-3 font-medium text-gray-900"><%= icon.name %></td>
                <td class="px-4 py-3 text-center">
                  <span class="px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-600 capitalize"><%= icon.style %></span>
                </td>
                <%= for size <- [16, 20, 24, 28, 32, 48] do %>
                  <td class="px-2 py-3 text-center relative">
                    <%= if size in icon.sizes do %>
                      <span class="text-green-600 font-black text-lg">✓</span>
                      <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-blue-50">
                        <div class="flex gap-0.5">
                          <%= for platform <- preferred_platforms(@platform_prefs, 2) do %>
                            <button
                              type="button"
                              phx-click={JS.dispatch("phx:copy_text", detail: %{text: get_platform_id_for_size(icon, platform, size), icon_id: icon.id, platform: platform})}
                              class={"p-1.5 rounded hover:bg-blue-200 #{platform_color(platform)}"}
                              title={"Copy #{platform} identifier for size #{size}"}
                              onclick="event.stopPropagation();"
                            >
                              <.platform_icon name={to_string(platform)} class="w-4 h-4" />
                            </button>
                          <% end %>
                        </div>
                      </div>
                    <% else %>
                      <span class="text-gray-300">✗</span>
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp default_size(sizes) do
    if 24 in sizes, do: 24, else: hd(sizes)
  end

  defp get_ios_id(icon) do
    size = default_size(icon.sizes) |> to_string()
    Map.get(icon.ios_identifiers, size, "N/A")
  end

  defp get_android_id(icon) do
    size = default_size(icon.sizes) |> to_string()
    Map.get(icon.android_identifiers, size, "N/A")
  end

  # Get the first N enabled platforms from user preferences
  defp preferred_platforms(prefs, count) do
    [:ios, :android, :react, :svelte, :filename]
    |> Enum.filter(&Map.get(prefs, &1, false))
    |> Enum.take(count)
  end

  defp platform_color(:ios), do: "text-blue-600"
  defp platform_color(:android), do: "text-green-600"
  defp platform_color(:react), do: "text-cyan-600"
  defp platform_color(:svelte), do: "text-orange-600"
  defp platform_color(:filename), do: "text-gray-600"
  defp platform_color(_), do: "text-gray-600"

  defp get_platform_id(icon, :ios), do: get_ios_id(icon)
  defp get_platform_id(icon, :android), do: get_android_id(icon)
  defp get_platform_id(icon, :react), do: react_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :svelte), do: svelte_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :filename), do: Icon.svg_filename(icon, default_size(icon.sizes))
  defp get_platform_id(_, _), do: "N/A"

  # Get platform identifier for a specific size
  defp get_platform_id_for_size(icon, :ios, size) do
    Map.get(icon.ios_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :android, size) do
    Map.get(icon.android_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :react, size), do: react_identifier(icon, size)
  defp get_platform_id_for_size(icon, :svelte, size), do: svelte_identifier(icon, size)
  defp get_platform_id_for_size(icon, :filename, size), do: Icon.svg_filename(icon, size)
  defp get_platform_id_for_size(_, _, _), do: "N/A"

  # React: PascalCase component import (e.g., <ArrowClockwise24Regular />)
  defp react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    style = icon.style |> String.capitalize()
    "<#{name}#{size}#{style} />"
  end

  # Svelte: snake_case with props (e.g., <Icon name="arrow_clockwise" size={24} variant="regular" />)
  defp svelte_identifier(icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} variant="#{icon.style}" />)
  end

  # Format numbers with k/m suffixes (1000 -> 1k, 3400 -> 3.4k, 1500000 -> 1.5m)
  defp format_number(n) when n >= 1_000_000 do
    formatted = Float.round(n / 1_000_000, 1)
    if formatted == trunc(formatted), do: "#{trunc(formatted)}m", else: "#{formatted}m"
  end

  defp format_number(n) when n >= 1_000 do
    formatted = Float.round(n / 1_000, 1)
    if formatted == trunc(formatted), do: "#{trunc(formatted)}k", else: "#{formatted}k"
  end

  defp format_number(n), do: to_string(n)

  # Format sync timestamp as relative time or date
  defp format_sync_time(nil), do: "Never"

  defp format_sync_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
    end
  end
end
