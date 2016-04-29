defmodule Channels.Adapter do
  @type config :: Keyword.t

  @type conn :: any
  @type chan :: any

  @type reason :: any

  @type name :: binary
  @type type :: (:direct | :topic | :fanout)
  @type opts :: Keyword.t

  @type queue_info   :: any
  @type consumer_tag :: binary

  @type payload :: binary
  @type meta    :: %{}

  @type ready   :: {:ready, meta}
  @type deliver :: {:deliver, payload, meta}
  @type cancel  :: {:cancel, meta}

  @type message :: any
  @type format  :: ready | deliver | cancel | :unknown

  @type routing_key :: binary

  # Connection
  @doc "Starts an amqp connection with the given config"
  @callback connect(config) :: {:ok, conn} | {:error, reason}

  @doc "Monitors the given amqp connection"
  @callback monitor(conn) :: reference

  @doc "Closes an amqp connection with the given config"
  @callback disconnect(conn) :: :ok

  # Channels
  @doc "Start a channel on the given connection"
  @callback open_channel(conn) :: {:ok, chan} | {:error, reason}

  @doc "Close a channel"
  @callback close_channel(chan) :: :ok

  # Declarations
  @doc "Declares an exchange"
  @callback declare_exchange(chan, name, type, opts) :: :ok | {:error, reason}

  @doc "Declares a queue"
  @callback declare_queue(chan, name, opts) :: {:ok, queue_info} | {:error, reason}

  # Subscribe
  @doc "Bind a queue to an exchange"
  @callback bind(chan, queue :: name, exchange :: name, opts) :: :ok

  @doc "Subscribe the given pid to a queue and receive messages"
  @callback consume(chan, queue :: name, pid, opts) :: {:ok, consumer_tag}

  @doc "Transform the given message to the expected format"
  @callback handle(message) :: format

  # Acknowledgement
  @doc "Ack a message"
  @callback ack(chan, meta, opts) :: :ok

  @doc "Nack a message"
  @callback nack(chan, meta, opts) :: :ok

  @doc "Reject a message"
  @callback reject(chan, meta, opts) :: :ok

  # Publication
  @doc "Publish a message"
  @callback publish(chan, exchange :: name, payload, routing_key, opts) :: :ok
end
