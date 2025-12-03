import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Icons storage path - set ICONS_PATH for local file serving
# When nil, icons are served from GitHub
if icons_path = System.get_env("ICONS_PATH") do
  config :fluentui_icons, :icons_path, icons_path
end

# Maintenance API key for remote task execution
if maintenance_key = System.get_env("MAINTENANCE_API_KEY") do
  config :fluentui_icons, :maintenance_api_key, maintenance_key
end

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :fluentui_icons, FluentuiIconsWeb.Endpoint, server: true
end

if config_env() == :prod do
  # Enable auto-migration on startup (can be disabled via env var)
  config :fluentui_icons, auto_migrate: System.get_env("AUTO_MIGRATE", "true") == "true"

  # Database configuration from individual env vars (preferred) or DATABASE_URL
  db_config =
    if database_url = System.get_env("DATABASE_URL") do
      [url: database_url]
    else
      [
        username: System.get_env("DB_USERNAME") || raise("DB_USERNAME not set"),
        password: System.get_env("DB_PASSWORD") || raise("DB_PASSWORD not set"),
        hostname: System.get_env("DB_HOSTNAME") || raise("DB_HOSTNAME not set"),
        database: System.get_env("DB_DATABASE") || raise("DB_DATABASE not set")
      ]
    end

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :fluentui_icons, FluentuiIcons.Repo,
    db_config ++
    [
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
      socket_options: maybe_ipv6
    ]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :fluentui_icons, FluentuiIconsWeb.Endpoint,
    url: [host: host, port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :fluentui_icons, FluentuiIconsWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :fluentui_icons, FluentuiIcons.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
