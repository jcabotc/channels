defmodule Channels.Monitor.SupervisorTest do
  use ExUnit.Case

  alias Channels.Monitor.Supervisor, as: MonitorSup

  defmodule TestMonitor do
    def start_link(config, _opts \\ []),
      do: Agent.start_link(notificator(config))

    def notificator(config) do
      pid = Keyword.fetch!(config, :pid)

      fn -> send(pid, {:started, config}) end
    end
  end

  test "monitors conn and notify pids" do
    test_pid = self
    config_1 = [config: 1, pid: test_pid]
    config_2 = [config: 2, pid: test_pid]

    configs = [first_conn: config_1,
               second_conn: config_2]

    opts = [monitor: TestMonitor]
    {:ok, _sup} = MonitorSup.start_link(configs, opts)

    assert_received {:started, ^config_1}
    assert_received {:started, ^config_2}
  end
end
