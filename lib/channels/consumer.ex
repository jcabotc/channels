defmodule Channels.Consumer do
  @moduledoc """
  A behaviour module for implementing an AMQP consumer.

  A Channels.Consumer is a process that can be used to keep state and
  provides a standard interface to execute code asynchronously when
  a message is received from the AMQP broker.

  It is based on a GenServer therefore include functionality for tracing
  and error reporting. It will also fit in a supervision tree.

  ## Example

  The Channels.Consumer behaviour abstracts the common broker-consumer
  interaction. Developers are only required to implement the callbacks
  and functionality they are interested in.

  Let's start with a code example and then explore the available callbacks.
  Imagine we want a consumer that receives messages from a queue "my_queue"
  binded to a fanout exchange "my_exchange", print the messages and respond
  with ack:

      defmodule Printer do
        use Channels.Consumer

        def handle_message(payload, _meta, header) do
          IO.puts(header <> payload)
          {:reply, :ack, header}
        end
      end

      # Exchange and queue config:
      config = %{
        exchange: %{
          name: "my_exchange",
          type: "fanout"
        },
        queue: %{
          name: "my_queue"
        }
      }

      # Start the consumer
      {:ok, _pid} = Channels.Consumer.start_link(Printer, "Received: ", config)

  We start our `Printer` by calling `start_link/3`, passing the module with
  the consumer implementation, its initial state (a header: "Received: ") and
  a map configuring the exchange and the queue.

  When we start the consumer, the following steps are taking place:

    1 - A GenServer is started.
    2 - The configured exchange is being declared.
    3 - The configured queue is being declared.
    4 - The queue is binded to the exchange.
    5 - The GenServer is subscribed to the queue.

  Imagine the message "Hello world!" is published to "my_exchange".
  `handle_message/3` will be called with:

    * payload: "Hello world!"
    * meta: Metadata sent by the broker plus the adapter and channel
      the consumer is using.
    * header: "Message received: ", the internal state of the consumer.

  It will print:

    "Message received: Hello world!"

  ## Callbacks

  There are 4 callbacks required to be implemented in a `Channels.Consumer`.
  By adding `use Channels.Consumer` to your module, all 6 will be defined,
  leaving it up to you to implement the ones you want to customize.

  ## Name Registration

  The name registration rules are the same of a `GenServer`.
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
  @callback init(initial :: term) :: Init.return_values

  @doc """
  Called when the broker informs that the consumer is subscribed as
  a consumer and is ready to start processing messages.

  If returns `{:noreply, state}` the consumer continues normally.
  If returns `{:stop, reason, state}` the consumer runs terminate/2 and
  then stops with the given reason.
  """
  @callback handle_ready(meta, state) :: Ready.return_values

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
  @callback handle_message(payload, meta, state) :: Deliver.return_values

  @doc """
  Called when the consumer exits.
  """
  @callback terminate(meta, state) :: term

  @doc """
  Invoked to change the state of the `Channels.Consumer` when a different version
  of a module is loaded (hot code swapping) and the state's term structure should be
  changed.

  `old_vsn` is the previous version of the module (defined by the `@vsn`
  attribute) when upgrading. When downgrading the previous version is wrapped in
  a 2-tuple with first element `:down`. `state` is the current state of the
  `GenServer` and `extra` is any extra data required to change the state.

  Returning `{:ok, new_state}` changes the state to `new_state` and the code
  change is successful.
  Returning `{:error, reason}` fails the code change with reason `reason` and
  the state remains as the previous state.

  If `code_change/3` raises the code change fails and the loop will continue
  with its previous state. Therefore this callback does not usually contain side effects.
  """
  @callback code_change(old_vsn :: term | {:down, term}, state, extra :: term) ::
              {:ok, state} |
              {:error, reason :: term}

  @doc false
  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour Channels.Consumer

      @doc false
      def init(initial) do
        {:ok, initial}
      end

      @doc false
      def handle_ready(_meta, state) do
        {:noreply, state}
      end

      @doc false
      def handle_message(_payload, _meta, state) do
        {:noreply, state}
      end

      @doc false
      def terminate(_meta, state) do
        :ok
      end

      @doc false
      def code_change(_old, state, _extra) do
        {:ok, state}
      end

      defoverridable [init: 1, handle_ready: 2, handle_message: 3,
                      terminate: 2, code_change: 3]
    end
  end

  @adapter Channels.Config.adapter
  @context Channels.Consumer.Context

  @type initial :: term
  @type config :: Keyword.t
  @type opts :: [GenServer.options | {:adapter, Adapter.t} | {:context, module}]

  @doc """
  Starts a new consumer server with the given configuration.

    * `callback_mod` - The module that implements de behaviour.
    * `initial` - The state that will be given to the init/2 callback.
    * `config` - The configuration of the consumer.
    * `opts` - `GenServer` options.
  """
  @spec start_link(module, initial, config, opts) :: GenServer.on_start
  def start_link(mod, initial, config, opts \\ []) do
    {args, opts} = build_args(mod, initial, config, opts)

    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Starts a new consumer without links (outside of a supervison tree).

  See `start_link\4` for more information.
  """
  @spec start(module, initial, config, opts) :: GenServer.on_start
  def start(mod, initial, config, opts \\ []) do
    {args, opts} = build_args(mod, initial, config, opts)

    GenServer.start(__MODULE__, args, opts)
  end

  defp build_args(mod, initial, config, opts) do
    {adapter, opts} = Keyword.pop(opts, :adapter, @adapter)
    {context, opts} = Keyword.pop(opts, :context, @context)

    {{adapter, context, config, mod, initial}, opts}
  end

  @doc """
  Declares the exchange and declares and binds the queue without starting
  a consumer.

    * `config` - The configuration of the consumer.
  """
  def declare(config, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, @adapter)
    context = Keyword.get(opts, :context, @context)

    case context.setup(config, adapter) do
      {:ok, %{chan: chan}} ->
        adapter.close_channel(chan)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sends an ack to the broker.

  This function is used to explicitly send an ack to the broker
  after a message has been received through `handle_message/3' when the
  ack cannot be sent as the return value of the message handling.

  The `meta` must be the second argument received in `handle_message/3`.
  The `opts` argument are options to be given to the underlaying AMQP
  adapter.

  Always returns :ok.
  """
  @spec ack(meta, opts :: Keyword.t) :: :ok
  def ack(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.ack(chan, meta, opts)
  end

  @doc """
  Sends a nack to the broker. Same behaviour as `ack/2`.
  """
  @spec nack(meta, opts :: Keyword.t) :: :ok
  def nack(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.nack(chan, meta, opts)
  end

  @doc """
  Sends a reject to the broker. Same behaviour as `reject/2`.
  """
  @spec reject(meta, opts :: Keyword.t) :: :ok
  def reject(%{adapter: adapter, chan: chan} = meta, opts \\ []) do
    adapter.reject(chan, meta, opts)
  end

  use GenServer

  alias Channels.Consumer.Handler.{Init, Ready, Deliver}

  @doc false
  def init({adapter, context, config, mod, initial}) do
    case context.setup(config, adapter) do
      {:ok, %{chan: chan}} ->
        mod_init(chan, adapter, mod, initial)

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp mod_init(chan, adapter, mod, initial) do
    state = %{chan: chan, mod: mod, adapter: adapter, given: initial}

    mod.init(initial)
    |> Init.handle(state)
  end

  @doc false
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

    mod.handle_ready(meta, given)
    |> Ready.handle(state)
  end

  @actions [:ack, :nack, :reject]
  defp deliver(payload, raw_meta, state) do
    {meta, mod, given} = prepare(raw_meta, state)

    mod.handle_message(payload, meta, given)
    |> Deliver.handle(state, meta)
  end

  defp cancel(raw_meta, state) do
    {meta, mod, given} = prepare(raw_meta, state)

    mod.terminate(meta, given)
    {:stop, :broker_cancel, state}
  end

  @doc false
  def terminate(reason, %{chan: chan, adapter: adapter}) do
    IO.inspect "TERMINATING #{inspect __MODULE__}: #{reason}"
    adapter.close_channel(chan)
  end

  defp prepare(raw_meta, %{chan: chan, mod: mod, adapter: adapter, given: given}) do
    meta = Map.merge(raw_meta, %{chan: chan, adapter: adapter})

    {meta, mod, given}
  end
end
