defmodule FluentuiIcons.RateLimiter do
  @moduledoc """
  Rate limiter using Hammer with ETS backend.
  Used to protect maintenance API endpoints from brute force attacks.
  """
  use Hammer, backend: :ets
end
