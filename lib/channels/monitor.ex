defmodule Channels.Monitor do
  @moduledoc """
  This module establishes connection with the given config,
  monitors the connection, and provides new channels.

  If the connection crashes all processes that requested a
  channel receive an exit signal with the reason given by
  the connection, and the monitor exits.
  """

  use GenServer

  alias Channels.Adapter
  @adapter Channels.Config.adapter

  @type opts :: [GenServer.option | {:adapter, Adapter.t}]

  @doc """
  Starts a new monitor.

    * `config` - The configuration to be given to the adapter.
    * `opts` - GenServer options plus :adapter (got from config
      by default).
  """
  @spec start_link(Adapter.config, opts) :: GenServer.on_start
  def start_link(config, opts \\ []) do
    {adapter, opts} = Keyword.pop(opts, :adapter, @adapter)

    GenServer.start_link(__MODULE__, {adapter, config}, opts)
  end

  @doc """
  Returns the connection and stores the given pid to be notified
  in case of connection crash.
  """
  @spec get_conn(GenServer.server, pid) :: Adapter.conn
  def get_conn(monitor, pid \\ self) do
    {:ok, GenServer.call(monitor, {:get, pid})}
  end

  def init({adapter, config}) do
    case adapter.connect(config) do
      {:ok, conn}      -> {:ok, build_state(adapter, conn)}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:get, pid}, _from, %{conn: conn, pids: pids} = state) do
    new_state = %{state | pids: [pid | pids]}
    {:reply, conn, new_state}
  end

  def handle_info({:DOWN, ref, _, _, conn_reason}, %{ref: ref} = state) do
    reason = {:connection_down, conn_reason}

    Enum.each(state.pids, &Process.exit(&1, reason))
    {:stop, reason, state}
  end

  def handle_info(_anything, state),
    do: {:noreply, state}

  def terminate({:connection_down, _reason}, _state),
    do: :ok

  def terminate(_any_reason, %{adapter: adapter, conn: conn}),
    do: adapter.disconnect(conn)

  defp build_state(adapter, conn) do
    ref = adapter.monitor(conn)
    %{adapter: adapter, ref: ref, conn: conn, pids: []}
  end
end
