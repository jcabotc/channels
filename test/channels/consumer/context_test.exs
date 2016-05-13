defmodule Channels.Consumer.ContextTest do
  use ExUnit.Case

  alias Channels.Consumer.Context

  @adapter Channels.Adapter.Sandbox

  @config [
    connection: "this value is ignored and a Conn object is provided for the test",
    exchange: [
      name: "my_exchange",
      type: :direct
    ],
    queue: [
      name: "my_queue",
      opts: [durable: true]
    ],
    bind: [routing_key: "the_key"]
  ]

  defmodule TestMonitor do
    def get_conn(conn), do: {:ok, conn}
  end

  test "sets up the context" do
    {:ok, conn} = @adapter.connect(:fake_config)
    config      = Keyword.put(@config, :connection, conn)

    assert {:ok, result} = Context.setup(config, @adapter, TestMonitor)
    assert %{chan: chan} = result

    expected = %{
      chan:         chan,
      exchange:     "my_exchange",
      queue:        "my_queue",
      consumer_tag: "a_consumer_tag"
    }
    assert expected == result

    expected_history = [
      {:declare_exchange, ["my_exchange", :direct, []]},
      {:declare_queue, ["my_queue", [durable: true]]},
      {:bind, ["my_queue", "my_exchange", [routing_key: "the_key"]]},
      {:consume, ["my_queue", self, []]}
    ]
    historic = @adapter.get_historic(chan)

    Enum.each expected_history, fn (expected) ->
      assert Enum.any?(historic, &(&1 == expected))
    end
  end
end
