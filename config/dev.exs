use Mix.Config

config :channels,
  adapter: Channels.Adapter.AMQP,
  connections: [:dev_connection]
