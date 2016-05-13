defmodule Channels.Config.ConnectionMissingError do
  defexception message: """
  Connections not defined.
  To define a connection named :my_conn add to your config:

    config :channels,
      connections: [:my_conn]
      ...

  By default when starting a connection the adapter will receive
  an empty configuration ([]). If you want to configure your
  connections:

    config :channels,
      connections: [:main_conn, :alt_conn]
      ...

    config :channels, :main_conn,
      host: "localhost",
      port: 1234,
      ...

    config :channels, :main_conn,
      "localhost:5678"
  """
end

