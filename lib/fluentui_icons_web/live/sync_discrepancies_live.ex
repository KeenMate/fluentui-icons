defmodule FluentuiIconsWeb.SyncDiscrepanciesLive do
  use FluentuiIconsWeb, :live_view

  alias FluentuiIcons.Sync.SyncRun

  @impl true
  def mount(_params, _session, socket) do
    sync_run = SyncRun.last_successful()

    socket =
      socket
      |> assign(:sync_run, sync_run)
      |> assign(:discrepancies, sync_run && sync_run.discrepancies || [])
      |> assign(:grouped, group_discrepancies(sync_run && sync_run.discrepancies || []))

    {:ok, socket}
  end

  defp group_discrepancies(discrepancies) do
    discrepancies
    |> Enum.group_by(& &1["icon_name"])
    |> Enum.sort_by(fn {name, _} -> name end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-6xl mx-auto px-4 py-8">
        <div class="mb-6">
          <a href="/" class="text-blue-600 hover:text-blue-800 flex items-center gap-1 text-sm">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back to Icons
          </a>
        </div>

        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">Sync Discrepancy Report</h1>

          <%= if @sync_run do %>
            <p class="text-sm text-gray-500 mb-6">
              Last sync: <%= Calendar.strftime(@sync_run.completed_at, "%Y-%m-%d %H:%M:%S UTC") %>
              &bull;
              <span class="font-medium text-orange-600"><%= length(@discrepancies) %> discrepancies</span>
            </p>

            <%= if length(@discrepancies) == 0 do %>
              <div class="text-center py-12">
                <svg class="w-16 h-16 mx-auto text-green-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p class="text-gray-600">No discrepancies found! All metadata matches actual SVG files.</p>
              </div>
            <% else %>
              <div class="mb-4 p-4 bg-orange-50 border border-orange-200 rounded-lg">
                <p class="text-sm text-orange-800">
                  <strong>What are discrepancies?</strong>
                  These are cases where Microsoft's metadata.json claims certain sizes/styles exist,
                  but the actual SVG files are missing from the repository. This is an upstream data quality issue.
                </p>
              </div>

              <div class="overflow-hidden">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Icon</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Missing Files</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for {icon_name, issues} <- @grouped do %>
                      <tr>
                        <td class="px-4 py-3 whitespace-nowrap">
                          <a href={"https://github.com/microsoft/fluentui-system-icons/tree/main/assets/#{icon_name}"}
                             target="_blank"
                             rel="noopener noreferrer"
                             class="font-medium text-blue-600 hover:text-blue-800 hover:underline">
                            <%= icon_name %>
                            <svg class="w-3 h-3 inline-block ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                          </a>
                        </td>
                        <td class="px-4 py-3">
                          <div class="flex flex-wrap gap-2">
                            <%= for issue <- issues do %>
                              <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800">
                                <%= issue["style"] %>/<%= issue["size"] %>px
                              </span>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="mt-6 p-4 bg-gray-50 rounded-lg">
                <h3 class="text-sm font-medium text-gray-700 mb-2">Summary by Style</h3>
                <div class="flex flex-wrap gap-4">
                  <%= for {style, count} <- count_by_style(@discrepancies) do %>
                    <div class="text-sm">
                      <span class="font-medium text-gray-900"><%= style %>:</span>
                      <span class="text-gray-600"><%= count %> missing</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="text-center py-12">
              <p class="text-gray-600">No sync has been completed yet. Run <code class="bg-gray-100 px-2 py-1 rounded">mix icons.download</code> first.</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp count_by_style(discrepancies) do
    discrepancies
    |> Enum.group_by(& &1["style"])
    |> Enum.map(fn {style, items} -> {style, length(items)} end)
    |> Enum.sort_by(fn {_, count} -> -count end)
  end
end
