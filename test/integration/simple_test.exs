defmodule Channels.Integration.SimpleTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule TestConsumer do
    use Channels.Consumer

    def start_link(handlers, config),
      do: Channels.Consumer.start_link(__MODULE__, handlers, config)

    def init(handlers),
      do: {:ok, handlers}

    def handle_ready(meta, handlers) do
      handlers[:ready].(meta)
      {:noreply, handlers}
    end

    def handle_message("instant: " <> rest, meta, handlers) do
      handlers[:instant].(rest, meta)
      {:reply, :ack, handlers}
    end

    def handle_message("delayed: " <> rest, meta, handlers) do
      callback = fn -> Channels.Consumer.reject(meta) end
      handlers[:delayed].(rest, meta, callback)
      {:noreply, handlers}
    end

    def terminate(meta, handlers) do
      handlers[:terminate].(meta)
    end
  end

  @config [
    connection: :main_connection,
    exchange: [name: "test_exchange", type: :fanout],
    queue: [name: "test_queue"]
  ]

  @adapter Channels.Config.adapter

  test "handles messages" do
    test_pid = self

    handlers = %{
      ready:     &send(test_pid, {:ready, &1}),
      instant:   &send(test_pid, {:instant, &1, &2}),
      delayed:   &send(test_pid, {:delayed, &1, &2, &3}),
      terminate: &send(test_pid, {:terminate, &1})
    }

    {:ok, consumer} = TestConsumer.start_link(handlers, @config)

    @adapter.send_ready(consumer, %{})
    assert_receive {:ready, %{chan: chan}}

    content = "a_message"
    @adapter.send_deliver(consumer, "instant: #{content}", %{})
    assert_receive {:instant, ^content, instant_meta}

    content = "another_message"
    @adapter.send_deliver(consumer, "delayed: #{content}", %{})
    assert_receive {:delayed, ^content, delayed_meta, callback}
    callback.()

    expected_history = [
      {:declare_exchange, ["test_exchange", :fanout, []]},
      {:declare_queue,    ["test_queue", []]},
      {:bind,             ["test_queue", "test_exchange", []]},
      {:consume,          ["test_queue", consumer, []]},
      {:ack,              [%{adapter: @adapter, chan: chan}, []]},
      {:reject,           [%{adapter: @adapter, chan: chan}, []]}
    ]
    assert expected_history == @adapter.get_historic(chan)

    Process.unlink(consumer)
    log = capture_log fn ->
      @adapter.send_cancel(consumer, %{})
    end
    assert_receive {:terminate, _meta}
    assert Regex.match?(~r/:broker_cancel/, log)
  end
end
