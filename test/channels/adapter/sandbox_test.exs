defmodule Channels.Adapter.SandboxTest do
  use ExUnit.Case

  alias Channels.Adapter.Sandbox, as: Adapter

  @config [fake: :config]

  @exchange %{
    name: "sandbox_exchange",
    type: :direct,
    opts: [some: :exchange_options]
  }

  @queue %{
    name: "sandbox_queue",
    opts: [some: :queue_options]
  }

  @routing_key "valid"

  test "get to consume messages" do
    assert {:ok, conn} = Adapter.connect(@config)
    assert {:ok, chan} = Adapter.open_channel(conn)

    %{name: exchange, type: type, opts: ex_opts} = @exchange
    assert :ok = Adapter.declare_exchange(chan, exchange, type, ex_opts)

    %{name: queue, opts: qu_opts} = @queue
    assert {:ok, _info} = Adapter.declare_queue(chan, queue, qu_opts)

    bind_opts = [routing_key: @routing_key]
    assert :ok = Adapter.bind(chan, queue, exchange, bind_opts)

    assert {:ok, "a_consumer_tag"} = Adapter.consume(chan, queue)

    Adapter.send_ready(self, :meta)
    assert_receive message
    assert {:ready, :meta} = Adapter.handle(message)

    payload = "the payload"
    assert :ok = Adapter.publish(chan, exchange, payload, @routing_key)

    assert_receive message
    assert {:deliver, ^payload, meta} = Adapter.handle(message)
    assert %{routing_key: @routing_key, delivery_tag: "a_delivery_tag"} == meta

    assert :ok = Adapter.reject(chan, :meta)
    assert :ok = Adapter.nack(chan, :meta)
    assert :ok = Adapter.ack(chan, :meta)

    expected_channels = [chan]
    assert expected_channels == Adapter.get_channels(conn)

    expected_historic = [
      {:declare_exchange, [exchange, type, ex_opts]},
      {:declare_queue, [queue, qu_opts]},
      {:bind, [queue, exchange, bind_opts]},
      {:consume, [queue, self, []]},
      {:publish, [exchange, payload, @routing_key, []]},
      {:reject, [:meta, []]},
      {:nack, [:meta, []]},
      {:ack, [:meta, []]}
    ]
    assert expected_historic == Adapter.get_historic(chan)

    assert :ok = Adapter.close_channel(chan)
    ref = Adapter.monitor(conn)

    assert :ok = Adapter.disconnect(conn)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
  end
end
