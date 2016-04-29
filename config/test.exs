use Mix.Config

config :channels,
  adapter: Channels.Adapter.Sandbox,
  connections: [:main_connection, :alt_connection]

config :channels, :main_connection, []
config :channels, :alt_connection,  []
