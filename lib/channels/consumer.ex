defmodule Channels.Consumer do
  defmacro __using__(_opts \\ []) do
    quote do
      def init(initial),
        do: {:ok, initial}

      def handle_ready(_meta, state),
        do: {:noreply, state}

      def handle_message(_payload, _meta, state),
        do: {:noreply, state}

      def terminate(_meta, state),
        do: :ok

      defoverridable [init: 1, handle_ready: 2, handle_message: 3, terminate: 2]
    end
  end

  use GenServer

  @adapter Channels.Config.adapter
  @chan_provider FakeProvider

  def start_link(mod, initial, config, opts \\ []) do
    {adapter, opts} = Keyword.pop(opts, :adapter, @adapter)
    {provider, opts} = Keyword.pop(opts, :chan_provider, @chan_provider)

    args = {mod, adapter, provider, config, initial}
    GenServer.start_link(__MODULE__, args, opts)
  end

  def ack(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.ack(chan, meta, opts)
  end

  def nack(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.nack(chan, meta, opts)
  end

  def reject(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.reject(chan, meta, opts)
  end

  def init({mod, adapter, provider, config, initial}) do
    chan = provider.setup(config)

    case mod.init(initial) do
      {:ok, given} ->
        {:ok, %{chan: chan, mod: mod, adapter: adapter, given: given}}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  def handle_info(message, %{adapter: adapter} = state) do
    case adapter.handle(message) do
      {:ready, raw_meta} ->
        ready(raw_meta, state)

      {:deliver, payload, raw_meta} ->
        deliver(payload, raw_meta, state)

      {:cancel, raw_meta} ->
        cancel(raw_meta, state)

      :unknown ->
        {:noreply, state}
    end
  end

  defp ready(raw_meta, state) do
    {meta, mod, given} = prepare(raw_meta, state)

    case mod.handle_ready(meta, given) do
      {:noreply, new_given} ->
        {:noreply, %{state | given: new_given}}

      {:stop, reason, new_given} ->
        {:stop, reason, %{state | given: new_given}}
    end
  end

  @actions [:ack, :nack, :reject]
  defp deliver(payload, raw_meta, state) do
    {meta, mod, given} = prepare(raw_meta, state)

    case mod.handle_message(payload, meta, given) do
      {:noreply, new_given} ->
        {:noreply, %{state | given: new_given}}

      {:reply, action, new_given} when action in @actions ->
        apply(__MODULE__, action, [meta])
        {:noreply, %{state | given: new_given}}

      {:reply, {action, opts}, new_given} when action in @actions ->
        apply(__MODULE__, action, [meta, opts])
        {:noreply, %{state | given: new_given}}

      {:stop, reason, new_given} ->
        {:stop, reason, %{state | given: new_given}}
    end
  end

  defp cancel(raw_meta, state) do
    {meta, mod, given} = prepare(raw_meta, state)

    mod.terminate(meta, given)
    {:stop, :broker_cancel, state}
  end

  defp prepare(raw_meta, %{chan: chan, mod: mod, adapter: adapter, given: given}) do
    meta = Map.merge(raw_meta, %{chan: chan, adapter: adapter})

    {meta, mod, given}
  end
end
