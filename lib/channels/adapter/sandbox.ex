defmodule Channels.Adapter.Sandbox do
  @behaviour Channels.Adapter

  defmodule Conn, do: defstruct [:config, :pid]
  defmodule Chan, do: defstruct [:conn, :pid]

  def connect(config) do
    {:ok, %Conn{config: config, pid: new}}
  end

  def monitor(%Conn{pid: conn_pid}) do
    Process.monitor(conn_pid)
  end

  def disconnect(%Conn{pid: conn_pid}) do
    stop(conn_pid)
  end

  def open_channel(%Conn{pid: conn_pid} = conn) do
    chan = %Chan{conn: conn, pid: new}
    add(conn_pid, chan)

    {:ok, chan}
  end

  def close_channel(%Chan{pid: chan_pid}) do
    stop(chan_pid)
  end

  def declare_exchange(%Chan{pid: chan_pid}, name, type, opts \\ []) do
    add(chan_pid, {:declare_exchange, [name, type, opts]})
  end

  def declare_queue(%Chan{pid: chan_pid}, name, opts \\ []) do
    {add(chan_pid, {:declare_queue, [name, opts]}), %{queue: "info"}}
  end

  def bind(%Chan{pid: chan_pid}, queue, exchange, opts \\ []) do
    add(chan_pid, {:bind, [queue, exchange, opts]})
  end

  def consume(%Chan{pid: chan_pid}, queue, pid \\ self, opts \\ []) do
    {add(chan_pid, {:consume, [queue, pid, opts]}), "a_consumer_tag"}
  end

  def handle({:ready, meta}) do
    {:ready, meta}
  end

  def handle({:deliver, payload, meta}) do
    {:deliver, payload, meta}
  end

  def handle({:cancel, meta}) do
    {:cancel, meta}
  end

  def handle(_anything) do
    :unknown
  end

  def ack(%Chan{pid: chan_pid}, meta, opts \\ []) do
    add(chan_pid, {:ack, [meta, opts]})
  end

  def nack(%Chan{pid: chan_pid}, meta, opts \\ []) do
    add(chan_pid, {:nack, [meta, opts]})
  end

  def reject(%Chan{pid: chan_pid}, meta, opts \\ []) do
    add(chan_pid, {:reject, [meta, opts]})
  end

  def publish(%Chan{pid: chan_pid}, exchange, payload, routing_key \\ "", opts \\ []) do
    pid = Keyword.get(opts, :test_pid, self)
    tag = Keyword.get(opts, :tag, "a_delivery_tag")

    send(pid, {:deliver, payload, %{routing_key: routing_key, delivery_tag: tag}})

    add(chan_pid, {:publish, [exchange, payload, routing_key, opts]})
  end

  # Helpers
  def get_channels(%Conn{pid: conn_pid}) do
    get(conn_pid)
  end

  def get_historic(%Chan{pid: chan_pid}) do
    get(chan_pid) |> Enum.reverse
  end

  def send_ready(pid, meta) do
    send(pid, {:ready, meta})
  end

  def send_deliver(pid, payload, meta) do
    send(pid, {:deliver, payload, meta})
  end

  def send_cancel(pid, meta) do
    send(pid, {:cancel, meta})
  end

  defp new(),             do: elem(Agent.start_link(fn -> [] end), 1)
  defp add(agent, value), do: Agent.update(agent, &[value | &1])
  defp get(agent),        do: Agent.get(agent, &(&1))
  defp stop(agent),       do: Agent.stop(agent)
end
