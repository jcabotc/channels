defmodule Channels do
  use Application

  @channels_sup Channels.Supervisor

  def start(_type, _args) do
    Channels.Supervisor.start_link(name: @channels_sup)
  end
end
