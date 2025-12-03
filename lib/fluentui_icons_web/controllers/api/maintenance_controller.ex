defmodule FluentuiIconsWeb.API.MaintenanceController do
  @moduledoc """
  Controller for maintenance API endpoints.
  Allows triggering maintenance tasks remotely via authenticated HTTP requests.

  Protected by:
  - API key authentication via X-API-Key header (MAINTENANCE_API_KEY env var)
  - Rate limiting (5 attempts per 5 minutes per IP)
  - Timing-safe comparison to prevent timing attacks

  Usage:
    curl -X POST -H "X-API-Key: your-key" https://example.com/api/maintenance/sync
  """
  use FluentuiIconsWeb, :controller

  # 5 attempts per 5 minutes per IP
  @rate_limit 5
  @rate_scale :timer.minutes(5)

  def run(conn, %{"task" => task}) do
    ip = get_client_ip(conn)
    api_key = get_api_key(conn)
    configured_key = Application.get_env(:fluentui_icons, :maintenance_api_key)

    case FluentuiIcons.RateLimiter.hit("maintenance:#{ip}", @rate_scale, @rate_limit) do
      {:deny, retry_after} ->
        conn
        |> put_resp_header("retry-after", to_string(div(retry_after, 1000)))
        |> put_status(429)
        |> json(%{error: "Too many attempts", retry_after_seconds: div(retry_after, 1000)})

      {:allow, _count} ->
        cond do
          is_nil(configured_key) or configured_key == "" ->
            conn |> put_status(503) |> json(%{error: "Maintenance API not configured"})

          is_nil(api_key) or api_key == "" ->
            conn |> put_status(401) |> json(%{error: "Missing X-API-Key header"})

          not Plug.Crypto.secure_compare(api_key, configured_key) ->
            conn |> put_status(401) |> json(%{error: "Invalid API key"})

          true ->
            execute_task(conn, task)
        end
    end
  end

  defp get_api_key(conn) do
    case Plug.Conn.get_req_header(conn, "x-api-key") do
      [key | _] -> key
      [] -> nil
    end
  end

  defp get_client_ip(conn) do
    # Check X-Forwarded-For for proxied requests (Traefik)
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] -> forwarded |> String.split(",") |> hd() |> String.trim()
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  # Task execution (async - returns immediately)
  defp execute_task(conn, "sync") do
    Task.start(fn -> FluentuiIcons.Sync.Worker.sync_all("api") end)
    json(conn, %{status: "started", task: "sync"})
  end

  defp execute_task(conn, "clean") do
    Task.start(fn -> FluentuiIcons.Repo.delete_all(FluentuiIcons.Icons.Icon) end)
    json(conn, %{status: "started", task: "clean"})
  end

  defp execute_task(conn, "cube") do
    Task.start(fn -> FluentuiIcons.Icons.refresh_metrics_cube() end)
    json(conn, %{status: "started", task: "cube"})
  end

  defp execute_task(conn, unknown) do
    conn
    |> put_status(400)
    |> json(%{error: "Unknown task", task: unknown, available: ["sync", "clean", "cube"]})
  end
end
