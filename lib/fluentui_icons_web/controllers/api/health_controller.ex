defmodule FluentuiIconsWeb.API.HealthController do
  use FluentuiIconsWeb, :controller

  alias FluentuiIcons.Icons

  @doc """
  Health check endpoint.

  Returns the current status of the application including icon count.

  ## Example Response

      {
        "status": "ok",
        "icon_count": 2847
      }
  """
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      icon_count: Icons.count()
    })
  end
end
