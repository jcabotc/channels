defmodule Channels.Context do
  @moduledoc """
  This module specifies the API a Context is required to
  implement.

  A context is a module with a setup/2 function that receives
  and adapter and a configuration that specifies what setup
  an AMQP related process needs in order to work (declare exchanges,
  bind queues, etc),

  See Channels.Context.Spec for the details about de format of the
  specification.
  """

  @type adapter :: Channels.Adapter.t
  @type spec    :: Channels.Context.Spec.spec
  @type result  :: %{}

  @doc """
  It sets up all the AMQP configuration needed to work, like
  exchanges and queue declarations, binding, and subscribing.

  As result it returns a map with a key providing optional
  information about the actions it took.
  """
  @callback setup(spec, adapter) ::
              :ok | {:error, reason :: term}
end
