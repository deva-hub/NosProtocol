defmodule NosProtocol.World.Handler do
  alias NosProtocol.World.Socket

  @type event :: String.t()
  @type packet :: map()

  @callback handle(event, Socket.t(), packet)

  defmacro __using__(opts) do
    @behaviour NosProtocol.World.Handler
    import NosProtocol.World.Socket

    quote bind_quoted: [opts: opts] do
      def handle(event, socket, packet) do
        Logger.warn(["PACKET Unimplemented ", event, " ", packet])
        {:ok, socket}
      end
    end

    defoverridable handle: 2
  end
end
