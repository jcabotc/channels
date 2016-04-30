defmodule Channels.Consumer do
  @moduledoc """
  This module specifies the `Channels.Consumer` behaviour.

  A consumer is a `GenServer` meant to receive messages from
  an AMQP broker.

  A default implementation and some response helpers (ack, reject, ...)
  are provided with the __using__ macro.

  The following example shows how it works.

    defmodule MyConsumer do
      use Channels.Consumer

      def start_link(handler, config) do
        Channels.Consumer.start_link(__MODULE__, handler, config)
      end

      def init(handler) do
        {:ok, %{handler: handler}}
      end

      def handle_ready(_meta, %{handler: handler} = state) do
        handler.start
        {:noreply, state}
      end

      def handle_message(payload, meta, %{handler: handler} = state) do
        case handler.handle(payload) do
          :ok ->
            {:reply, :ack, state}

          :ack_in_1_second ->
            spawn fn ->
              :timer.sleep(1000)
              Channels.Consumer.ack(meta)
            end
            {:noreply, state}

          :error ->
            {:reply, :reject, state}

          {:fatal, reason} ->
            Channels.Consumer.reject(meta)
            {:stop, reason, state}
        end
      end

      def terminate(meta, %{handler: handler}) do
        handler.stop
      end
    end
  """

  @type state :: term
  @type reason :: term
  @type meta :: map
  @type payload :: binary
  @type action :: :ack | :nack | :reject

  @doc """
  Called when the consumer is connected to the broker.

  If returns `{:ok, state}` the consumer starts waiting for messages.
  If returns `{:stop, reason}` the consumer is stopped with that reason
  without running `terminate/2`
  """
  @callback init(initial :: term) ::
              {:ok, state} |
              {:stop, reason}

  @doc """
  Called when the broker informs that the consumer is subscribed as
  a consumer and is ready to start processing messages.

  If returns `{:noreply, state}` the consumer continues normally.
  If returns `{:stop, reason, state}` the consumer runs terminate/2 and
  then stops with the given reason.
  """
  @callback handle_ready(meta, state) ::
              {:noreply, state} |
              {:stop, reason, state}

  @doc """
  Called when a message is received from the broker.

  If returns `{:noreply, state}` the consumer continues normally without
  responding the broker (Is expected to ack, nack or reject using the
  provided functions (`ack/1`, `nack/1` and `reject/1`) that expect the
  meta argument.
  If returns `{:reply, action, state}` where action is `:ack`, `:nack` or
  `:reject` responds to the broker with the given action. If some opts
  have to be provided to the adapter (like `requeue: false`)
  `{:noreply, {action, opts}, state} can also be returned.
  If returns {:stop, reason, state} the consumer runs terminate/2 and
  then stops with the given reason.
  """
  @callback handle_message(payload, meta, state) ::
              {:noreply, state} |
              {:reply, action, state} |
              {:reply, {action, opts :: Keyword.t}, state} |
              {:stop, reason, state}

  @doc """
  Called when the consumer exits.
  """
  @callback terminate(meta, state) :: term

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Channels.Consumer

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

  @type callback_mod :: module
  @type initial :: term
  @type config :: Keyword.t
  @type opts :: [GenServer.options | {:adapter, Adapter.t} | {:chan_provider, module}]

  @doc """
  Starts a new consumer server with the given configuration.

    * `callback_mod` - The module that implements de behaviour.
    * `initial` - The state that will be given to the init/2 callback.
    * `config` - The configuration of the consumer.
    * `opts` - `GenServer` options.
  """
  @spec start_link(callback_mod, initial, config, opts) :: GenServer.on_start
  def start_link(mod, initial, config, opts \\ []) do
    {adapter, opts}  = Keyword.pop(opts, :adapter, @adapter)
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
