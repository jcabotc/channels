defmodule Channels.Consumer.Handler.Shared do
  defmacro is_timeout(value) do
    quote do
      unquote(value) == :infinity
      or is_integer(unquote(value))
      and unquote(value) >= 0
    end
  end
end
