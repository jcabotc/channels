defmodule Channels.Integration.FailingConnectionTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule TestConsumer do
    use Channels.Consumer

    def start_link(test_pid, config, opts) do
      Channels.Consumer.start_link(__MODULE__, test_pid, config, opts)
    end

    def handle_message(payload, meta, test_pid) do
      send(test_pid, {:message, payload, meta})
      {:reply, :ack, test_pid}
    end
  end

  @config [
    connection: :main_connection,
    exchange: [name: "test_exchange", type: :fanout],
    queue: [name: "test_queue"]
  ]

  @adapter Channels.Config.adapter
  @consumer_name :channels_integration_failing_connection_test_consumer

  test "restarts properly" do
    args  = [self, @config, [name: @consumer_name]]
    child = Supervisor.Spec.worker(TestConsumer, args)

    {:ok, _sup} = Supervisor.start_link([child], strategy: :one_for_one)

    payload = "the_payload"
    @adapter.send_deliver(@consumer_name, payload, %{})
    assert_receive({:message, ^payload, %{chan: chan}})

    log = capture_log fn ->
      @adapter.disconnect(chan.conn)
    end
    assert Regex.match?(~r/:connection_down/, log)

    @adapter.send_deliver(@consumer_name, payload, %{})
    assert_receive({:message, ^payload, %{chan: new_chan}})

    assert chan != new_chan
  end
end
