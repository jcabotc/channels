defmodule Channels.Publisher.ContextTest do
  use ExUnit.Case

  alias Channels.Publisher.Context

  @adapter Channels.Adapter.Sandbox

  @config [
    connection: "this value is ignored and a Conn object is provided for the test",
    exchange: [
      name: "my_exchange",
      type: :direct
    ]
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
      chan:     chan,
      exchange: "my_exchange"
    }
    assert expected == result

    expected_history = [
      {:declare_exchange, ["my_exchange", :direct, []]}
    ]
    historic = @adapter.get_historic(chan)

    Enum.each expected_history, fn (expected) ->
      assert Enum.any?(historic, &(&1 == expected))
    end
  end
end
