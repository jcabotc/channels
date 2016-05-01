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
      :error         -> raise Channels.Config.AdapterMissingError
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
        raise Channels.Config.ConnectionMissingError
    end
  end

  defp get_conn_config(config, name) do
    case Keyword.fetch(config, name) do
      {:ok, conn_config} -> conn_config
      :error             -> @default_config
    end
  end
end
