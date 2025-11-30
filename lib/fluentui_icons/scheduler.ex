defmodule FluentuiIcons.Scheduler do
  @moduledoc """
  Quantum scheduler for running periodic tasks.

  Configured in config/config.exs to run daily icon sync at 3 AM.
  """
  use Quantum, otp_app: :fluentui_icons
end
