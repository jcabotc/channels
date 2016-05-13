defmodule Channels.Adapter.AMQPTest do
  use ExUnit.Case
  @moduletag :amqp_server

  alias Channels.Adapter.AMQP, as: Adapter

  @config Application.get_env(:channels, :main_connection)

  @exchange %{
    name: "__test__.channels_adapter_amqp_test_exchange",
    type: :direct,
    opts: [durable: false, auto_delete: true]
  }

  @queue %{
    name: "__test__.channels_adapter_amqp_test_queue",
    opts: [durable: false, auto_delete: true]
  }

  @routing_key "valid"

  test "get to consume messages" do
    assert {:ok, conn} = Adapter.connect(@config)
    assert {:ok, chan} = Adapter.open_channel(conn)

    %{name: exchange, type: type, opts: opts} = @exchange
    assert :ok = Adapter.declare_exchange(chan, exchange, type, opts)

    %{name: queue, opts: opts} = @queue
    assert {:ok, _info} = Adapter.declare_queue(chan, queue, opts)

    opts = [routing_key: @routing_key]
    assert :ok = Adapter.bind(chan, queue, exchange, opts)

    assert {:ok, _consumer_tag} = Adapter.consume(chan, queue)

    assert_receive message
    assert {:ready, _meta} = Adapter.handle(message)

    payload = "the payload"
    assert :ok = Adapter.publish(chan, exchange, payload, @routing_key)

    assert_receive message
    assert {:deliver, ^payload, meta} = Adapter.handle(message)

    assert :ok = Adapter.publish(chan, exchange, payload, "invalid")
    refute_receive _message

    assert :ok = Adapter.reject(chan, meta)
    assert_receive message
    assert {:deliver, ^payload, meta} = Adapter.handle(message)

    assert :ok = Adapter.nack(chan, meta)
    assert_receive message
    assert {:deliver, ^payload, meta} = Adapter.handle(message)

    assert :ok = Adapter.ack(chan, meta)
    refute_receive _message

    assert :ok = Adapter.close_channel(chan)
    ref = Adapter.monitor(conn)

    assert :ok = Adapter.disconnect(conn)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end
end
