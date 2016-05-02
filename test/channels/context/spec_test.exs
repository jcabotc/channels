defmodule Channels.Context.SpecTest do
  use ExUnit.Case

  alias Channels.Context.Spec

  test "conn_name/1" do
    spec = Spec.new(connection: :the_connection)

    assert {:ok, :the_connection} == Spec.conn_name(spec)
  end

  test "conn_name/1 when missing" do
    spec = Spec.new([])

    assert {:error, {:missing_config, _details}} = Spec.conn_name(spec)
  end

  test "exchange/1" do
    spec = Spec.new(exchange: [name: "ex_name", type: :fanout])
    expected = %{name: "ex_name", type: :fanout, opts: []}

    assert {:ok, expected} == Spec.exchange(spec)
  end

  test "exchange/1 when name is missing" do
    spec = Spec.new(exchange: [type: :fanout])

    assert {:error, {:missing_config, _details}} = Spec.exchange(spec)
  end

  test "queue/1" do
    spec = Spec.new(queue: [name: "ex_name", opts: [durable: true]])
    expected = %{name: "ex_name", opts: [durable: true]}

    assert {:ok, expected} == Spec.queue(spec)
  end

  test "queue/1 when queue config is missing" do
    spec = Spec.new([])

    assert {:error, {:missing_config, _details}} = Spec.queue(spec)
  end
end
