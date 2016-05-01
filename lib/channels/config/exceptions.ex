defmodule Channels.Config.AdapterMissingError do
  defexception message: """
  Adapter not defined.
  By default only the AMQP adapter is included.
  To use it add to your configuration:

    config :channels,
      adapter: Channels.Adapter.AMQP
      ...

  Also add AMQP to your mix.exs file as a dependency and start it as an application:

    def application do
      [applications: [:amqp, ...],
       ...]
    end

    defp deps do
      [{:amqp, "0.1.4"},
       ...]
    end
  """
end

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

