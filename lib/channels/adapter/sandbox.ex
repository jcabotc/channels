defmodule Channels.Adapter.Sandbox do
  @behaviour Channels.Adapter

  defmodule Conn, do: defstruct [:config, :pid]
  defmodule Chan, do: defstruct [:conn, :pid]

  def connect(config),
    do: {:ok, %Conn{config: config, pid: new}}

  def monitor(%Conn{pid: conn_pid}),
    do: Process.monitor(conn_pid)

  def disconnect(%Conn{pid: conn_pid}),
    do: stop(conn_pid)

  def open_channel(%Conn{pid: conn_pid} = conn) do
    chan = %Chan{conn: conn, pid: new}
    add(conn_pid, chan)

    {:ok, chan}
  end

  def close_channel(%Chan{pid: chan_pid}),
    do: stop(chan_pid)

  def declare_exchange(%Chan{pid: chan_pid}, name, type, opts \\ []),
    do: add(chan_pid, {:declare_exchange, [name, type, opts]})

  def declare_queue(%Chan{pid: chan_pid}, name, opts \\ []),
    do: {add(chan_pid, {:declare_queue, [name, opts]}), %{queue: "info"}}

  def bind(%Chan{pid: chan_pid}, queue, exchange, opts \\ []),
    do: add(chan_pid, {:bind, [queue, exchange, opts]})

  def consume(%Chan{pid: chan_pid}, queue, pid \\ self, opts \\ []),
    do: {add(chan_pid, {:consume, [queue, pid, opts]}), "a_consumer_tag"}

  def handle({:ready, meta}),
    do: {:ready, meta}

  def handle({:deliver, payload, meta}),
    do: {:deliver, payload, meta}

  def handle({:cancel, meta}),
    do: {:cancel, meta}

  def handle(_anything),
    do: :unknown

  def ack(%Chan{pid: chan_pid}, meta, opts \\ []),
    do: add(chan_pid, {:ack, [meta, opts]})

  def nack(%Chan{pid: chan_pid}, meta, opts \\ []),
    do: add(chan_pid, {:nack, [meta, opts]})

  def reject(%Chan{pid: chan_pid}, meta, opts \\ []),
    do: add(chan_pid, {:reject, [meta, opts]})

  def publish(%Chan{pid: chan_pid}, exchange, payload, routing_key \\ "", opts \\ []) do
    pid = Keyword.get(opts, :test_pid, self)
    tag = Keyword.get(opts, :tag, "a_delivery_tag")

    send(pid, {:deliver, payload, %{routing_key: routing_key, delivery_tag: tag}})

    add(chan_pid, {:publish, [exchange, payload, routing_key, opts]})
  end

  # Helpers
  def get_channels(%Conn{pid: conn_pid}),
    do: get(conn_pid)

  def get_historic(%Chan{pid: chan_pid}),
    do: get(chan_pid) |> Enum.reverse

  def send_ready(pid, meta),
    do: send(pid, {:ready, meta})

  def send_deliver(pid, payload, meta),
    do: send(pid, {:deliver, payload, meta})

  def send_cancel(pid, meta),
    do: send(pid, {:cancel, meta})

  defp new(),             do: elem(Agent.start_link(fn -> [] end), 1)
  defp add(agent, value), do: Agent.update(agent, &[value | &1])
  defp get(agent),        do: Agent.get(agent, &(&1))
  defp stop(agent),       do: Agent.stop(agent)
end
