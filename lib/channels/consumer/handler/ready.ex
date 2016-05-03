defmodule Channels.Consumer.Handler.Ready do
  import Channels.Consumer.Handler.Shared, only: [is_timeout: 1]

  @type state  :: term
  @type reason :: term

  @type return_values :: {:noreply, state} |
                         {:noreply, state, timeout | :hibernate} |
                         {:stop, reason}

  def handle({:noreply, given}, state) do
    {:noreply, %{state | given: given}}
  end

  def handle({:noreply, given, timeout}, state)
  when is_timeout(timeout) do
    {:noreply, %{state | given: given}}
  end

  def handle({:noreply, given, :hibernate}, state) do
    {:noreply, %{state | given: given}, :hibernate}
  end

  def handle({:stop, reason, given}, state) do
    {:stop, reason, %{state | given: given}}
  end

  def handle(anything, _state) do
    raise "bad ready/2 return value: #{anything}"
  end
end
