defmodule Channels.ConfigTest do
  use ExUnit.Case

  alias Channels.Config

  test "adapter/1" do
    config = [adapter: FakeAdapter]
    assert FakeAdapter == Config.adapter(config)
  end

  test "adapter/1 when adapter missing" do
    assert_raise Channels.AdapterMissingError, fn ->
      Config.adapter([])
    end
  end

  test "conn_configs/1 with no definition" do
    default_name = Config.default_conn_name

    expected = [{default_name, []}]
    assert expected == Config.conn_configs([])
  end

  test "conn_configs/1 with default definition" do
    default_name = Config.default_conn_name
    conn_config  = [host: "localhost", port: 1234]
    config       = [connection: conn_config]

    expected = [{default_name, conn_config}]
    assert expected == Config.conn_configs(config)
  end

  test "conn_configs/1 with many definitions" do
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
end
