defmodule NosProtocol.World.Handshake do
  @moduledoc false

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          session_id: non_neg_integer
        }

  defstruct username: "",
            password: "",
            session_id: 0
end
