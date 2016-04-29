defmodule Channels.Monitor do
  use GenServer

  @adapter Channels.Config.adapter

  def start_link(config, opts \\ []) do
    {adapter, opts} = Keyword.pop(opts, :adapter, @adapter)

    GenServer.start_link(__MODULE__, {adapter, config}, opts)
  end

  def get_conn(monitor) do
    GenServer.call(monitor, :get_conn)
  end

  def init({adapter, config}) do
    case adapter.connect(config) do
      {:ok, conn} ->
        {:ok, build_state(adapter, conn)}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_call(:get_conn, {pid, _tag}, %{conn: conn, pids: pids} = state) do
    new_state = %{state | pids: [pid | pids]}

    {:reply, conn, new_state}
  end

  def handle_info({:DOWN, ref, _type, _pid, reason}, %{ref: ref} = state) do
    Enum.each(state.pids, &Process.exit(&1, reason))

    {:stop, :connection_down, state}
  end

  def handle_info(_anything, state) do
    {:noreply, state}
  end

  def terminate(:connection_down, _state) do
    :ok
  end

  def terminate(_any_reason, %{adapter: adapter, conn: conn}) do
    adapter.disconnect(conn)
  end

  defp build_state(adapter, conn) do
    ref = adapter.monitor(conn)

    %{adapter: adapter, ref: ref, conn: conn, pids: []}
  end
end
