defmodule Channels.ConfigTest do
  use ExUnit.Case

  alias Channels.Config

  test "adapter/1" do
    config = [adapter: FakeAdapter]
    assert FakeAdapter == Config.adapter(config)
  end

  @default_adapter Channels.Adapter.AMQP

  test "adapter/1 when adapter missing" do
    assert @default_adapter == Config.adapter([])
  end

  test "conn_configs/1" do
    conn_config_1 = [host: "localhost", port: 1234]

    config = [
      connections: [:first_conn, :last_conn],
      first_conn: conn_config_1
    ]

    expected = [
      {:first_conn, conn_config_1},
      {:last_conn, []}
    ]
    assert expected == Config.conn_configs(config)
  end

  test "conn_configs/1 when connections missing" do
    assert_raise Config.ConnectionMissingError, fn ->
      Config.conn_configs([])
    end
  end
end
