defmodule Channels.ConsumerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Channels.Consumer

  defmodule TestConsumer do
    use Consumer

    def start_link(pid, config, opts \\ []),
      do: Consumer.start_link(__MODULE__, pid, config, opts)

    def init(pid),
      do: {:ok, pid}

    def handle_ready(meta, pid) do
      send(pid, {:handle_ready, meta})
      {:noreply, pid}
    end

    def handle_message("direct: " <> action, meta, pid) do
      send(pid, {:handle_message, :direct, action, meta})
      {:reply, String.to_atom(action), pid}
    end

    def handle_message("delayed: " <> action, meta, pid) do
      send(pid, {:handle_message, :delayed, action, meta})
      {:ok, _task} = Task.start_link fn ->
        apply(Consumer, String.to_atom(action), [meta])
      end

      {:noreply, pid}
    end

    def terminate(meta, pid),
      do: send(pid, {:terminate, meta})
  end

  defmodule TestContext do
    def setup([test_pid: test_pid], adapter) do
      {:ok, conn} = adapter.connect(:fake_config)
      {:ok, chan} = adapter.open_channel(conn)

      send(test_pid, {:context_setup, chan})
      {:ok, %{chan: chan}}
    end
  end

  @adapter Channels.Adapter.Sandbox

  test "consumers properly" do
    test_pid = self

    config = [test_pid: test_pid]
    opts   = [adapter: @adapter, context: TestContext]

    {:ok, consumer} = TestConsumer.start_link(test_pid, config, opts)

    assert_receive {:context_setup, chan}

    meta = %{chan: chan, adapter: @adapter}

    @adapter.send_ready(consumer, %{})
    assert_receive {:handle_ready, ^meta}

    @adapter.send_deliver(consumer, "direct: ack", %{})
    @adapter.send_deliver(consumer, "delayed: reject", %{})
    assert_receive {:handle_message, :direct, "ack", ^meta}
    assert_receive {:handle_message, :delayed, "reject", ^meta}

    :timer.sleep(10)

    historic = @adapter.get_historic(chan)
    assert Enum.any?(historic, &(&1 == {:ack, [meta, []]}))
    assert Enum.any?(historic, &(&1 == {:reject, [meta, []]}))

    Process.unlink(consumer)
    log = capture_log fn ->
      @adapter.send_cancel(consumer, %{})
      assert_receive {:terminate, ^meta}
    end

    assert Regex.match?(~r/:broker_cancel/, log)
  end
end
