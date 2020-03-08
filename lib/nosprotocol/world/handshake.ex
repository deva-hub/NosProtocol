defmodule NosProtocol.World.Handshake do
  @moduledoc """
  A wrapper for NosProtocol's `Handshake` message.
  """

  defstruct [
    :username,
    :password,
    :session_id
  ]

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          session_id: non_neg_integer()
        }
end
