# Channels

An application to manage AMQP consumers and publishers.

## Installation

You can use channels in your projects in two steps:

1. Add plug and your adapter of choice (currently amqp) to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [{:amqp, "0.1.4"},
       {:channels, "~> 0.0.1"}]
    end
    ```

2. List both `:amqp` and `:channels` as your application dependencies:

    ```elixir
    def application do
      [applications: [:amqp, :channels]]
    end
    ```

## Connections

To publish or consume messages you first have to configure a connection.

```elixir
config :channels,
  connections: [:main_connection, :another_connection]

config :channels, :main_connection,
  host: "localhost",
  port: 5672
```

On the example above we are configuring two connections named `:main_connection`
and `:alt_connection`.

The configuration for the `:main_connection` will be passed to the underlying adapter when connecting.

The `:another_connection` does not have a custom configuration, an empty keyword list will be passed to the adapter.

## Publishing messages

A `Channels.Publisher` is a GenServer that holds a channel and is associated with an exchange.

It provides a `publish/4` function to publish messages to the AMQP broker.

```elixir
config = [
  connection: :main_connection,
  exchange: [name: "my-exchange", type: :direct]
]

# Start a publisher
{:ok, pid} = Channels.Publisher.start_link(config)

# Send a message
:ok = Channels.Publisher.publish(pid, "payload", "routing_key")
```

On the example above, on the `start_link/1` call, the following steps are taking place:

  1 - A GenServer is started.
  2 - A new channel is opened using the specified connection (`:main_connection`).
  3 - An exchange named my-exchange of type direct is being declared to the AMQP broker.

After that we can send messages to the broker with the `publish/3`.

The routing key is optional and defaults to `""`.

## Consuming messages

A `Channels.Consumer` is a GenServer that can be used to keep state and provides a
standard interface to execute code when a message is received from the AMQP broker.

```elixir
defmodule MyConsumer do
  use Channels.Consumer

  def start_link(callback) do
    Channels.Consumer.start_link(__MODULE__, callback)
  end

  def init(callback) do
    {:ok, %{callback: callback}}
  end

  def handle_message(payload, _metadata, %{callback: callback} = state) do
    callback.(payload)
    {:reply, :ack, callback}
  end
end

config = [
  connection: :main_connection,
  exchange: [name: "my-exchange", type: :direct],
  queue: [name: "my-queue", type: :direct, opts: [durable: true]],
  bind: [routing_key: "my-key"]
]

my_pid   = self
callback = &send(my_pid, &1)

# Start a consumer
{:ok, pid} = Channels.Consumer.start_link(callback, config)

# Imagine a message is sent to "my-queue" with "my-key" routing_key and with
# the payload: "Hello World!"

receive do
  message -> IO.puts(message)
end
# Prints: "Hello World!"
```

On the example above, on the `start_link/2` call, the following steps are taking place:

  1 - A GenServer is started.
  2 - A new channel is opened using the specified connection (`:main_connection`).
  3 - An exchange named my-exchange of type direct is being declared to the AMQP broker.
  4 - A queue named my-queue is being declared to the AMQP broker.
  5 - The queue is binded to the exchange with the given bind options

After that messages sent to "my-queue" will be sent as messages to the consumer
as callbacks to the `handle_message/3` function.

### Asynchronous ack's

In the example above we have shown how a consumer handles a message and inmediately ack's it using the `{:reply, :ack, state}` return value.

Sometimes you do not want to ack or reject a message inmediately because another process is going to handle the message, and whether we respond with an ack or a reject depends on the result of the processing.

For such cases the `Channels.Consumer` module provides the functions `ack/1`, `nack/1` and `reject/1`.

```elixir
defmodule MyProcessor do
  def process(message, on_success, on_failure) do
    case do_process(message) do
      :ok    -> on_success.()
      :error -> on_failure.()
    end
  end

  def do_process(message) do
    # do something
  end
end

defmodule MyConsumer do
  use Channels.Consumer

  def handle_message(payload, meta, state) do
    on_success = fn -> Channels.Consumer.ack(meta) end
    on_failure = fn -> Channels.Consumer.reject(meta, requeue: false) end

    Task.start(MyProcessor, :process, [payload, on_success, on_failure])

    {:noreply, state}
  end
end
```

In this example we are not acking or rejecting the message synchronously (we return `{:noreply, state}`.

We are starting a task that performs the message handling, and providing the task some callbacks ack or reject the message by itself when the job is done.

## License

Channels source code is released under Apache 2 License.
Check LICENSE file for more information.
