defmodule Channels do
  use Application
  require Logger

  @channels_sup Channels.Supervisor

  def start(_type, _args) do
    Logger.info("========== CONFIG ==========")
    Logger.info(inspect Application.get_all_env(:channels))
    Logger.info(inspect Channels.Config.conn_configs)
    Logger.info("============================")

    Channels.Supervisor.start_link(name: @channels_sup)
  end
end
