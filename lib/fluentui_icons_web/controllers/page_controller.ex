defmodule FluentuiIconsWeb.PageController do
  use FluentuiIconsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
