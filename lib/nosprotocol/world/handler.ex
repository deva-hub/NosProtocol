defmodule NosProtocol.World.Handler do
  @moduledoc """
  Post connection packet handler.
  """
  alias NosProtocol.World.Socket

  @type event :: String.t()
  @type packet :: map()

  @callback handle(event, Socket.t(), packet) :: {:ok, Socket.t()} | {:error, map}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour NosProtocol.World.Handler
      import NosProtocol.World.Socket

      def handle(_, socket, _) do
        {:ok, socket}
      end

      defoverridable handle: 3
    end
  end
end
