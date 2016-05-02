defmodule Channels.Consumer.Context do
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
         {:ok, exchange}  <- declare_exchange(chan, spec, adapter),
         {:ok, queue}     <- declare_queue(chan, spec, adapter),
         {:ok, bind_opts} <- bind_opts(spec),
         :ok              <- adapter.bind(chan, queue, exchange, bind_opts),
         {:ok, cons_tag}  <- adapter.consume(chan, queue) do
      {:ok, %{chan: chan, exchange: exchange, queue: queue, consumer_tag: cons_tag}}
    end
  end

  defp declare_exchange(chan, spec, adapter) do
    with {:ok, %{name: name, type: type, opts: opts}} <- Spec.exchange(spec),
         :ok <- adapter.declare_exchange(chan, name, type, opts) do
      {:ok, name}
    end
  end

  defp declare_queue(chan, spec, adapter) do
    with {:ok, %{name: name, opts: opts}} <- Spec.queue(spec),
         {:ok, _queue_info} <- adapter.declare_queue(chan, name, opts) do
      {:ok, name}
    end
  end

  defp bind_opts(spec) do
    {:ok, %{opts: opts}} = Spec.bind_opts(spec)

    {:ok, opts}
  end
end
