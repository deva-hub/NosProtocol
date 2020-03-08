defmodule NosProtocol.World do
  require Logger
  alias NosLib.{Crypto, ErrorMessage}
  alias NosProtocol.World.{Handshake, Socket}

  @type reply :: map()
  @type params :: map()

  @callback connect(params(), Socket.t()) :: {:ok, reply(), Socket.t()} | {:error, reply()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour :ranch_protocol
      @behaviour NosProtocol.Portal
      import NosProtocol.Socket

      @impl true
      @doc false
      def start_link(ref, socket, transport, opts) do
        NosProtocol.Portal.start_link(__MODULE__, ref, socket, transport, opts)
      end

      @doc false
      def init({ref, parent, socket, transport, opts}) do
        NosProtocol.Portal.enter_loop(__MODULE__, {ref, parent, socket, transport, opts})
      end

      @doc false
      def loop(socket) do
        NosProtocol.Portal.__loop__(__MODULE__, socket)
      end

      @doc false
      def terminate(:session_already_used, state) do
        send_packet(socket, NosLib.serialize(%ErrorMessage{reason: :session_already_used}))
        NosProtocol.Portal.__terminate__(reason, state)
      end

      def terminate(reason, state) do
        NosProtocol.Portal.__terminate__(reason, state)
      end

      defoverridable terminate: 2
    end
  end

  def start_link(module, ref, socket, transport, opts \\ []) do
    :proc_lib.start_link(module, :init, [{ref, self(), socket, transport, opts}])
  end

  def enter_loop(module, {ref, parent, socket, transport, opts}) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)

    unless handler = opts[:handler] do
      raise ArgumentError, "missing :handler option on use NosProtocol.World"
    end

    crypto = Keyword.get(opts, :crypto, Crypto.Login)
    timeout = Keyword.get(opts, :timeout, 300_000)

    socket = %Socket{
      socket: socket,
      crypto: crypto,
      transport: transport,
      transport_pid: parent,
      timeout: timeout,
      handler: handler,
      stream: %Handshake{}
    }

    module.loop(socket)
  end

  def __loop__(module, socket) do
    case Socket.recv_packet(socket) do
      {:ok, packet} ->
        Logger.info(["PACKET ", packet])
        parse(module, socket, packet)

      {:error, reason} ->
        module.terminate(reason, socket)
    end
  end

  defp parse(%{stream: %Handshake{session_id: nil}} = socket, packet) do
    loop(%{
      socket
      | key_base: packet,
        session_id: packet,
        stream: %{socket.stream | session_id: packet}
    })
  end

  defp parse(%{stream: %Handshake{username: nil, password: nil}} = socket, packet) do
    [username, _, password, transaction_id] = String.split(packet)

    socket.connect(
      %{socket.stream | username: username, password: password}
      %{socket | stream: nil, transaction_id: transaction_id},
    )
  end

  defp parse(socket, packet) do
    [transaction_id, event_id, packet] = String.split(packet, " ", parts: 3)

    case socket.handle(event_id, NosLib.deserialize(packet), %{
           socket
           | transaction_id: transaction_id
         }) do
      {:ok, socket} ->
        loog(socket)

      {:error, reason} ->
        module.terminate(:session_already_used, socket)
    end
  end

  def __terminate__(_, socket) do
    Socket.close(socket)
    :ok
  end
end
