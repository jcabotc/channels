if Code.ensure_loaded?(AMQP) do

  defmodule Channels.Adapter.AMQP do
    @behaviour Channels.Adapter

    alias AMQP.{Connection, Channel, Exchange, Queue, Basic}

    def connect(config) do
      Connection.open(config)
    end

    def monitor(%Connection{pid: pid}) do
      Process.monitor(pid)
    end

    def disconnect(%Connection{} = conn) do
      Connection.close(conn)
      :ok
    end

    def open_channel(%Connection{} = conn) do
      Channel.open(conn)
    end

    def close_channel(%Channel{} = chan) do
      Channel.close(chan)
      :ok
    end

    def declare_exchange(%Channel{} = chan, name, type, opts \\ []) do
      Exchange.declare(chan, name, type, opts)
    end

    def declare_queue(%Channel{} = chan, name, opts \\ []) do
      Queue.declare(chan, name, opts)
    end

    def bind(%Channel{} = chan, queue, exchange, opts \\ []) do
      Queue.bind(chan, queue, exchange, opts)
    end

    def consume(%Channel{} = chan, queue, pid \\ self, opts \\ []) do
      Basic.consume(chan, queue, pid, opts)
    end

    def handle({:basic_consume_ok, meta}) do
      {:ready, meta}
    end

    def handle({:basic_deliver, payload, meta}) do
      {:deliver, payload, meta}
    end

    def handle({:basic_cancel, meta}) do
      {:cancel, meta}
    end

    def handle(_anything) do
      :unknown
    end

    def ack(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []) do
      Basic.ack(chan, tag, opts)
    end

    def nack(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []) do
      Basic.nack(chan, tag, opts)
    end

    def reject(%Channel{} = chan, %{delivery_tag: tag}, opts \\ []) do
      Basic.reject(chan, tag, opts)
    end

    def publish(%Channel{} = chan, exchange, payload, routing_key \\ "", opts \\ []) do
      Basic.publish(chan, exchange, routing_key, payload, opts)
    end
  end

end
