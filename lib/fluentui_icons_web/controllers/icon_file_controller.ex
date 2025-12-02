defmodule FluentuiIconsWeb.IconFileController do
  @moduledoc """
  Serves icon SVG files directly without directory scanning.
  Uses runtime configuration for icons path.
  """
  use FluentuiIconsWeb, :controller

  @valid_styles ~w(regular filled color light)

  defp icons_dir do
    Application.get_env(:fluentui_icons, :icons_path)
  end

  def show(conn, %{"style" => style, "filename" => filename}) do
    case icons_dir() do
      nil ->
        # Icons not configured locally, return 404
        send_resp(conn, 404, "Icons not available locally")

      dir ->
        if style in @valid_styles and String.ends_with?(filename, ".svg") do
          path = Path.join([dir, style, filename])

          if File.exists?(path) do
            conn
            |> put_resp_content_type("image/svg+xml")
            |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
            |> send_file(200, path)
          else
            send_resp(conn, 404, "Not found")
          end
        else
          send_resp(conn, 400, "Invalid request")
        end
    end
  end
end
