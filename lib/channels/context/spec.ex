defmodule Channels.Context.Spec do
  @moduledoc """
  This modules parses context specification.

  A context specification defines how exchanges, queues
  or any broker related resources must be declared or
  configured before an AMQP process interacts with them.

  ## Example

  Imagine you defined a connection named :my_connection on
  your Mix config:

    config :channels,
      ...
      connections: [:my_connection]

    config :channels, :my_connection,
      host: "localhost",
      port: 1234
      ...

  This is an example of possible configuration for a
  consumer that subscribes to a queue "my_queue" to the
  direct exchange "my_exchange" only for the routing_key
  "the_key" through the previously defined connection:

    [
      connection: :my_connection,
      exchange: [
        name: "my_exchange",
        type: :direct,
        opts: [durable: true]
      ],
      queue: [
        name: "my_queue",
        opts: [durable: true, exclusive: true]
      ],
      bind: [routing_key: "the_key"]
    ]

  """
  @type spec :: Keyword.t
  @type t :: %__MODULE__{spec: spec}

  defstruct [:spec]

  alias Channels.Context.Spec

  @doc "Returns a new Spec struct given a configuration"
  @spec new(spec) :: t
  def new(spec) when is_list(spec),
    do: %Spec{spec: spec}

  @doc "Returns a new Spec struct given a configuration"
  @spec conn_name(t) :: {:ok, name :: atom} | {:error, reason :: term}
  def conn_name(%Spec{spec: spec}) do
    case Keyword.fetch(spec, :connection) do
      {:ok, conn_name} ->
        {:ok, conn_name}
      :error ->
        {:error, {:missing_config, "connection name (atom) is not present"}}
    end
  end

  @doc """
  Returns the exchange configuration. It expects at least the following fields:

    exchange: [name: "exchange_name", type: :direct]

  Also it can include an :opts field which is a keyword list of options to
  be given to the adapter when declaring the exchange.
  """
  @spec exchange(t) ::
          {:ok, %{name: binary, type: atom, opts: Keyword.t}} |
          {:error, reason :: term}
  def exchange(%Spec{spec: spec}) do
    case Keyword.fetch(spec, :exchange) do
      {:ok, section} ->
        exchange_config(section)
      :error ->
        {:error, {:missing_config, "exchange configuration is not present: #{spec}"}}
    end
  end

  @doc """
  Returns the queue configuration. It expects at least the name field:

    queue: [name: "queue_name"]

  Also it can include an :opts field which is a keyword list of options to
  be given to the adapter when declaring the queue.
  """
  @spec queue(t) ::
          {:ok, %{name: binary, opts: Keyword.t}} |
          {:error, reason :: term}
  def queue(%Spec{spec: spec}) do
    case Keyword.fetch(spec, :queue) do
      {:ok, section} ->
        queue_config(section)
      :error ->
        {:error, {:missing_config, "queue configuration is not present: #{spec}"}}
    end
  end

  @doc """
  Returns the binding configuration. It is optional. By default it is an
  empty keyword list.

    bind: [routing_key: "my_key", ...]

  It can include a set of option to be given to the adapter when binding the queue
  and the exchange.
  """
  @spec bind_opts(t) :: {:ok, %{opts: Keyword.t}}
  def bind_opts(%Spec{spec: spec}) do
    opts = Keyword.get(spec, :bind, [])

    {:ok, %{opts: opts}}
  end

  defp exchange_config(section) do
    name = Keyword.get(section, :name, :missing)
    type = Keyword.get(section, :type, :missing)
    opts = Keyword.get(section, :opts, [])

    case {name, type} do
      {:missing, _type} ->
        {:error, {:missing_config, "name missing on exchange configuration"}}
      {_name, :missing} ->
        {:error, {:missing_config, "type missing on exchange configuration"}}
      {name, type} ->
        {:ok, %{name: name, type: type, opts: opts}}
    end
  end

  defp queue_config(section) do
    name = Keyword.get(section, :name, :missing)
    opts = Keyword.get(section, :opts, [])

    case name do
      :missing ->
        {:error, {:missing_config, "name missing on queue configuration"}}
      name ->
        {:ok, %{name: name, opts: opts}}
    end
  end
end
