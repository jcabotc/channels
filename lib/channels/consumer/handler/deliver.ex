defmodule Channels.Consumer.Handler.Deliver do
  alias Channels.Consumer

  import Channels.Consumer.Handler.Shared, only: [is_timeout: 1]

  @type state  :: term
  @type action :: :ack | :nack | :reject
  @type opts   :: Keyword.t
  @type reason :: term

  @type return_values :: {:reply, action, state} |
                         {:reply, action, state, timeout | :hibernate} |
                         {:noreply, state} |
                         {:noreply, state, timeout | :hibernate} |
                         {:stop, reason, state}

  @actions [:ack, :nack, :reject]

  def handle({:reply, action, given}, state, meta)
  when action in @actions do
    apply(Consumer, action, [meta])
    {:noreply, %{state | given: given}}
  end

  def handle({:reply, action, given, timeout}, state, meta)
  when action in @actions and is_timeout(timeout) do
    apply(Consumer, action, [meta])
    {:noreply, %{state | given: given}}
  end

  def handle({:reply, action, given, :hibernate}, state, meta)
  when action in @actions do
    apply(Consumer, action, [meta])
    {:noreply, %{state | given: given}, :hibernate}
  end

  def handle({:reply, {action, opts}, given}, state, meta)
  when action in @actions do
    apply(Consumer, action, [meta, opts])
    {:noreply, %{state | given: given}}
  end

  def handle({:reply, {action, opts}, given, timeout}, state, meta)
  when action in @actions and is_timeout(timeout) do
    apply(Consumer, action, [meta, opts])
    {:noreply, %{state | given: given}}
  end

  def handle({:reply, {action, opts}, given, :hibernate}, state, meta)
  when action in @actions do
    apply(Consumer, action, [meta, opts])
    {:noreply, %{state | given: given}, :hibernate}
  end

  def handle({:noreply, given}, state, _meta) do
    {:noreply, %{state | given: given}}
  end

  def handle({:noreply, given, timeout}, state, _meta)
  when is_timeout(timeout) do
    {:noreply, %{state | given: given}}
  end

  def handle({:noreply, given, :hibernate}, state, _meta) do
    {:noreply, %{state | given: given}, :hibernate}
  end

  def handle({:stop, reason, given}, state, _meta) do
    {:stop, reason, %{state | given: given}}
  end

  def handle(anything, _state, _meta) do
    raise "bad deliver/3 return value: #{anything}"
  end
end
