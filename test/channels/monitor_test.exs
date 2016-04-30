defmodule Channels.MonitorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Channels.Monitor

  @adapter Channels.Adapter.Sandbox
  @config [fake: "config"]

  test "monitors conn and notify pids" do
    Process.flag(:trap_exit, true)

    {:ok, monitor} = Monitor.start_link(@config, adapter: @adapter)

    conn = Monitor.get_conn(monitor)
    assert ^conn = Monitor.get_conn(monitor)

    log = capture_log fn ->
      @adapter.disconnect(conn)
    end
    assert Regex.match?(~r/:connection_down/, log)

    assert_receive {:EXIT, ^monitor, {:connection_down, :normal}}
    assert_receive {:EXIT, ^monitor, {:connection_down, :normal}}
  end
end
