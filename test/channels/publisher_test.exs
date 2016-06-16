defmodule Channels.PublisherTest do
  use ExUnit.Case

  alias Channels.Publisher

  defmodule TestContext do
    def setup([test_pid: test_pid, exchange: exchange], adapter) do
      {:ok, conn} = adapter.connect(:fake_config)
      {:ok, chan} = adapter.open_channel(conn)

      send(test_pid, {:context_setup, chan})
      {:ok, %{chan: chan, exchange: exchange}}
    end
  end

  @adapter Channels.Adapter.Sandbox

  test "consumers properly" do
    test_pid = self
    exchange = "my_exchange"

    config = [test_pid: test_pid, exchange: exchange]
    opts   = [adapter: @adapter, context: TestContext]

    {:ok, publisher} = Publisher.start_link(config, opts)

    assert_receive {:context_setup, chan}

    payload     = "the_payload"
    routing_key = "the_routing_key"

    assert :ok = Publisher.publish(publisher, payload, routing_key)

    :timer.sleep(10)

    expected_historic = {:publish, [exchange, payload, routing_key, []]}
    historic          = @adapter.get_historic(chan)

    assert Enum.any?(historic, &(&1 == expected_historic))
  end

  test "declare/2" do
    test_pid = self
    exchange = "my_exchange"

    config = [test_pid: test_pid, exchange: exchange]
    opts   = [adapter: @adapter, context: TestContext]

    assert :ok == Channels.Publisher.declare(config, opts)
    assert_receive {:context_setup, chan}

    refute Process.alive?(chan.pid)
  end
end
