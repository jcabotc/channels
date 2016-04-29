defmodule Channels.Monitor.Supervisor do
  use Supervisor

  @monitor Channels.Monitor

  def start_link(configs, opts \\ []) do
    {monitor, opts} = Keyword.pop(opts, :monitor, @monitor)

    Supervisor.start_link(__MODULE__, {monitor, configs}, opts)
  end

  def init({monitor, configs}) do
    children = Enum.map configs, fn {name, config} ->
      worker(monitor, [config], id: name)
    end

    supervise(children, strategy: :one_for_one)
  end
end
