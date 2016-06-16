defmodule Channels.Publisher do
  @moduledoc """
  A behaviour module for implementing an AMQP publisher.

  A Channels.Publisher is a process that holds a channel and an
  exchange name, and provides functions to send messages to the
  AMQP broker.

  It is based on a GenServer therefore include functionality for tracing
  and error reporting. It will also fit in a supervision tree.

  ## Example

  The Channels.Publisher behaviour hides low level details and provides
  a `publish/4` function to publish messages.

  Let's start with a code example.
  Imagine we want a publisher that publishes numbers to a direct exchange
  "my_exchange" with a routing key tagging whether the number is positive
  negative or zero.

      # Exchange config:
      config = %{
        exchange: %{
          name: "my_exchange",
          type: "direct"
        }
      }

      # Start the publisher
      {:ok, pid} = Channels.Publisher.start_link(config)

      # Send a message
      Channels.Publisher.publish(pid, "3", "positive")
      Channels.Publisher.publish(pid, "0", "zero")
      Channels.Publisher.publish(pid, "-2", "negative")

  We start our `Channels.Publisher` process by calling `start_link/1`, passing
  exchange configuration.

  When we start the publisher, the following steps are taking place:

    1 - A GenServer is started.
    2 - A new channel is created for this publisher.
    3 - The configured exchange is being declared.

  After that the publisher is ready to be used. We are using the `publish/3`
  function to publish 3 messages to the AMQP broker containing "3", "0", and "-2"
  as payloads, and "positive, "zero", and "negative" as routing keys respectively.

  ## Name Registration

  The name registration rules are the same of a `GenServer`.
  """

  @adapter Channels.Config.adapter
  @context Channels.Publisher.Context

  @type config :: Keyword.t
  @type opts :: [GenServer.options | {:adapter, Adapter.t} | {:context, module}]

  @doc """
  Starts a new publisher with the given configuration.

    * `config` - The configuration of the publisher.
    * `opts` - `GenServer` options.
  """
  @spec start_link(config, opts) :: GenServer.on_start
  def start_link(config, opts \\ []) do
    {args, opts} = build_args(config, opts)

    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Starts a new consumer without links (outside of a supervison tree).

  See `start_link\2` for more information.
  """
  @spec start(config, opts) :: GenServer.on_start
  def start(config, opts \\ []) do
    {args, opts} = build_args(config, opts)

    GenServer.start(__MODULE__, args, opts)
  end

  defp build_args(config, opts) do
    {adapter, opts} = Keyword.pop(opts, :adapter, @adapter)
    {context, opts} = Keyword.pop(opts, :context, @context)

    {{adapter, context, config}, opts}
  end

  @doc """
  Declares the exchangewithout starting a publisher.

    * `config` - The configuration of the publisher.
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

  @type payload     :: binary
  @type routing_key :: binary
  @type options     :: Keyword.t

  @doc """
  Publishes a message to the configured exchange.

    * `pid` - The publisher pid.
    * `payload` - The message to be published.
    * `routing_key` - (optional) The routing key.
    * `options` - (optional) Options to be passed to the adapter.
  """
  @spec publish(pid, payload, routing_key, options) :: :ok
  def publish(publisher, payload, routing_key \\ "", opts \\ []),
    do: GenServer.cast(publisher, {:publish, payload, routing_key, opts})

  use GenServer

  @doc false
  def init({adapter, context, config}) do
    case context.setup(config, adapter) do
      {:ok, %{chan: chan, exchange: exchange}} ->
        {:ok, %{adapter: adapter, chan: chan, exchange: exchange}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc false
  def handle_cast({:publish, payload, routing_key, opts}, state) do
    %{adapter: adapter, chan: chan, exchange: exchange} = state
    adapter.publish(chan, exchange, payload, routing_key, opts)

    {:noreply, state}
  end
end
