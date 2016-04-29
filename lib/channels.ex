defmodule Channels do
  use Application

  def start(_type, _args) do
    Channels.Supervisor.start_link
  end
end
