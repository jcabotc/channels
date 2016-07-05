defmodule Channels.MonitorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Channels.Monitor

  @adapter Channels.Adapter.Sandbox
  @config [fake: "config"]

  test "monitors conn and notify pids" do
    Process.flag(:trap_exit, true)

    {:ok, monitor} = Monitor.start_link(@config, adapter: @adapter)

    {:ok, conn_1} = Monitor.get_conn(monitor)
    assert {:ok, ^conn_1} = Monitor.get_conn(monitor)

    log = capture_log fn ->
      @adapter.disconnect(conn_1)
      :timer.sleep(10)
    end
    assert Regex.match?(~r/Connection down/, log)
    assert Regex.match?(~r/Successfully reconnected/, log)

    assert_receive {:EXIT, ^monitor, {:connection_down, :normal}}
    assert_receive {:EXIT, ^monitor, {:connection_down, :normal}}

    {:ok, conn_2} = Monitor.get_conn(monitor)
    assert conn_1 != conn_2
    log = capture_log fn ->
      @adapter.disconnect(conn_2)
      :timer.sleep(10)
    end
    assert Regex.match?(~r/Connection down/, log)
    assert Regex.match?(~r/Successfully reconnected/, log)

    assert_receive {:EXIT, ^monitor, {:connection_down, :normal}}
  end
end
