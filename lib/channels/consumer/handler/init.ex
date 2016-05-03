defmodule Channels.Consumer.Handler.Init do
  import Channels.Consumer.Handler.Shared, only: [is_timeout: 1]

  @type state  :: term
  @type reason :: term

  @type return_values :: {:ok, state} |
                         {:ok, state, timeout | :hibernate} |
                         :ignore |
                         {:stop, reason}

  def handle({:ok, given}, state) do
    {:ok, %{state | given: given}}
  end

  def handle({:ok, given, timeout}, state)
  when is_timeout(timeout) do
    {:ok, %{state | given: given}, timeout}
  end

  def handle({:ok, given, :hibernate}, state) do
    {:ok, %{state | given: given}, :hibernate}
  end

  def handle(:ignore, _state) do
    :ignore
  end

  def handle({:stop, reason}, _state) do
    {:stop, reason}
  end

  def handle(anything, _state) do
    raise "bad init/1 return value: #{anything}"
  end
end
