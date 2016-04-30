defmodule Channels.Adapter do
  @moduledoc """
  This module specifies the adapter API that an AMQP adapter is
  required to implement.
  """

  @type t :: module

  @type config :: Keyword.t

  @type conn :: term
  @type chan :: term

  @type exchange :: binary
  @type type     :: (:direct | :topic | :fanout)
  @type queue    :: binary
  @type opts :: Keyword.t

  @type payload     :: binary
  @type meta        :: %{}
  @type routing_key :: binary

  # Connection
  @doc "Starts an AMQP connection with the given config"
  @callback connect(config) ::
              {:ok, conn} | {:error, reason :: term}

  @doc "Monitors the given AMQP connection"
  @callback monitor(conn) :: reference

  @doc "Closes an AMQP connection with the given config"
  @callback disconnect(conn) :: :ok

  # Channels
  @doc "Start a channel on the given connection"
  @callback open_channel(conn) ::
              {:ok, chan} | {:error, reason :: term}

  @doc "Close a channel"
  @callback close_channel(chan) :: :ok

  # Declarations
  @doc "Declares an exchange"
  @callback declare_exchange(chan, exchange, type, opts) ::
              :ok | {:error, reason :: term}

  @doc "Declares a queue"
  @callback declare_queue(chan, queue, opts) ::
              {:ok, queue_info :: term} | {:error, reason :: term}

  # Subscribe
  @doc "Bind a queue to an exchange"
  @callback bind(chan, queue, exchange, opts) :: :ok

  @doc "Subscribe the given pid to a queue and receive messages"
  @callback consume(chan, queue, pid, opts) ::
              {:ok, consumer_tag :: binary}

  @doc "Transform the given message to the expected format"
  @callback handle(message :: term) ::
              {:ready, meta} |
              {:deliver, payload, meta} |
              {:cancel, meta} |
              :unknown

  # Acknowledgement
  @doc "Ack a message"
  @callback ack(chan, meta, opts) :: :ok

  @doc "Nack a message"
  @callback nack(chan, meta, opts) :: :ok

  @doc "Reject a message"
  @callback reject(chan, meta, opts) :: :ok

  # Publication
  @doc "Publish a message"
  @callback publish(chan, exchange, payload, routing_key, opts) :: :ok
end
