defmodule Channels.AdapterMissingError do
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

defmodule Channels.ConnectionMissingError do
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

defmodule Channels.Config do
  @moduledoc """
  This module provides functions to access the Mix configuration.
  """

  @config Application.get_all_env(:channels)

  alias Channels.Adapter
  @type config :: Keyword.t

  @doc "Configured AMQP adapter."
  @spec adapter(config) :: Adapter.t | no_return
  def adapter(config \\ @config) do
    case Keyword.fetch(config, :adapter) do
      {:ok, adapter} -> adapter
      :error         -> raise Channels.AdapterMissingError
    end
  end

  @default_config []

  @type conn_name    :: atom
  @type conn_config  :: Keyword.t
  @type conn_configs :: [{conn_name, conn_config}]

  @doc "Configured connections"
  @spec conn_configs(config) :: conn_configs | no_return
  def conn_configs(config \\ @config) do
    case Keyword.fetch(config, :connections) do
      {:ok, names} ->
        Enum.map(names, &{&1, get_conn_config(config, &1)})
      :error ->
        raise Channels.ConnectionMissingError
    end
  end

  defp get_conn_config(config, name) do
    case Keyword.fetch(config, name) do
      {:ok, conn_config} -> conn_config
      :error             -> @default_config
    end
  end
end
