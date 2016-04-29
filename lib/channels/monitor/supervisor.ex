defmodule Channels.Monitor.Supervisor do
  use Supervisor

  @monitor Channels.Monitor

  def start_link(configs, opts \\ []) do
    {monitor, opts} = Keyword.pop(opts, :monitor, @monitor)

    Supervisor.start_link(__MODULE__, {monitor, configs}, opts)
  end

  def init({monitor, configs}) do
    children = Enum.map(configs, &spec(monitor, &1))

    supervise(children, strategy: :one_for_one)
  end

  defp spec(monitor, {name, config}) do
    worker(monitor, [config, [name: name]], id: name)
  end
end
