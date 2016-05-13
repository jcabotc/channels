defmodule Channels.Publisher.Context do
  @behaviour Channels.Context

  alias Channels.Context.Spec

  @monitor Channels.Monitor

  def setup(spec_config, adapter, monitor \\ @monitor) do
    spec_config
    |> Spec.new
    |> do_setup(adapter, monitor)
  end

  defp do_setup(spec, adapter, monitor) do
    with {:ok, conn_name} <- Spec.conn_name(spec),
         {:ok, conn}      <- monitor.get_conn(conn_name),
         {:ok, chan}      <- adapter.open_channel(conn),
         {:ok, exchange}  <- declare_exchange(chan, spec, adapter) do
      {:ok, %{chan: chan, exchange: exchange}}
    end
  end

  defp declare_exchange(chan, spec, adapter) do
    with {:ok, %{name: name, type: type, opts: opts}} <- Spec.exchange(spec),
         :ok <- adapter.declare_exchange(chan, name, type, opts) do
      {:ok, name}
    end
  end
end
