defmodule Channels.Monitor do
  @moduledoc """
  This module establishes connection with the given config,
  monitors the connection, and provides new channels.

  If the connection crashes all processes that requested a
  channel receive an exit signal with the reason given by
  the connection, and the monitor exits.
  """

  use GenServer
  require Logger

  alias Channels.Adapter
  @adapter Channels.Config.adapter
  @intervals [0, 10, 100, 1000, 5000]

  @type opts :: [GenServer.option | {:adapter, Adapter.t}]

  @doc """
  Starts a new monitor.

    * `config` - The configuration to be given to the adapter.
    * `opts` - GenServer options plus :adapter (got from config
      by default).
  """
  @spec start_link(Adapter.config, opts) :: GenServer.on_start
  def start_link(config, opts \\ []) do
    {adapter, opts}   = Keyword.pop(opts, :adapter, @adapter)
    {intervals, opts} = Keyword.pop(opts, :retry_intervals, @intervals)

    GenServer.start_link(__MODULE__, {adapter, intervals, config}, opts)
  end

  @doc """
  Returns the connection and stores the given pid to be notified
  in case of connection crash.
  """
  @spec get_conn(GenServer.server, pid) :: Adapter.conn
  def get_conn(monitor, pid \\ self) do
    {:ok, GenServer.call(monitor, {:get, pid}, :infinity)}
  end

  def init({adapter, intervals, config}) do
    case adapter.connect(config) do
      {:ok, conn}      -> {:ok, build_state(adapter, conn, config, intervals)}
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
    {:noreply, reconnect(state)}
  end

  def handle_info(_anything, state),
    do: {:noreply, state}

  def terminate({:connection_down, _reason}, _state),
    do: :ok

  def terminate(_any_reason, %{adapter: adapter, conn: conn}),
    do: adapter.disconnect(conn)

  defp reconnect(%{intervals: intervals} = state) do
    reconnect(state, intervals)
  end
  defp reconnect(state, [last_interval]) do
    reconnect(state, [last_interval, last_interval])
  end
  defp reconnect(%{adapter: adapter, config: config} = state, [interval | rest]) do
    log_reconnecting(interval, state)
    :timer.sleep(interval)

    case adapter.connect(config) do
      {:ok, conn}       -> successful_reconnection(state, conn)
      {:error, _reason} -> reconnect(state, rest)
    end
  end

  defp successful_reconnection(%{adapter: adapter} = state, conn) do
    log_reconnected(state)
    ref = adapter.monitor(conn)
    %{state | conn: conn, ref: ref, pids: []}
  end

  defp build_state(adapter, conn, config, intervals) do
    ref = adapter.monitor(conn)
    %{adapter: adapter, ref: ref, conn: conn, pids: [], config: config, intervals: intervals}
  end

  defp log_reconnecting(interval, %{config: config}) do
    Logger.warn("Connection down: Waiting #{interval}ms to retry reconnection (config: #{inspect config})")
  end

  defp log_reconnected(%{config: config}) do
    Logger.warn("Successfully reconnected (config: #{inspect config})")
  end
end
