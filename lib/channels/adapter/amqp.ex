defmodule Channels.Adapter.AMQP do
  @behaviour Channels.Adapter

  alias AMQP.{Connection, Channel, Exchange, Queue, Basic}

  def connect(config),
    do: Connection.open(config)

  def monitor(%Connection{pid: pid}),
    do: Process.monitor(pid)

  def disconnect(%Connection{} = conn) do
    Connection.close(conn)
    :ok
  end

  def open_channel(%Connection{} = conn),
    do: Channel.open(conn)

  def close_channel(%Channel{} = chan) do
    Channel.close(chan)
    :ok
  end

  def declare_exchange(%Channel{} = chan, name, type, opts \\ []),
    do: Exchange.declare(chan, name, type, opts)

  def declare_queue(%Channel{} = chan, name, opts \\ []),
    do: Queue.declare(chan, name, opts)

  def bind(%Channel{} = chan, queue, exchange, opts \\ []),
    do: Queue.bind(chan, queue, exchange, opts)

  def consume(%Channel{} = chan, queue, pid \\ self, opts \\ []),
    do: Basic.consume(chan, queue, pid, opts)

  def handle({:basic_consume_ok, meta}),
    do: {:ready, meta}

  def handle({:basic_deliver, payload, meta}),
    do: {:deliver, payload, meta}

  def handle({:basic_cancel, meta}),
    do: {:deliver, meta}

  def handle(_anything),
    do: :unknown

  def ack(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []),
    do: Basic.ack(chan, tag, opts)

  def nack(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []),
    do: Basic.nack(chan, tag, opts)

  def reject(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []),
    do: Basic.reject(chan, tag, opts)

  def publish(%Channel{} = chan, exchange, payload, routing_key \\ "", opts \\ []),
    do: Basic.publish(chan, exchange, routing_key, payload, opts)
end
