defmodule NosProtocol.Portal do
  require Logger
  alias NosLib.{Crypto, ErrorMessage}
  alias NosProtocol.Portal.Socket

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
      def terminate(:bad_case, state) do
        Socket.reply(socket, NosLib.serialize(%ErrorMessage{reason: :bad_case}))
        NosProtocol.Portal.__terminate__(reason, state)
      end

      def terminate(:outdated_client, state) do
        Socket.reply(socket, NosLib.serialize(%ErrorMessage{reason: :outdated_client}))
        NosProtocol.Portal.__terminate__(reason, state)
      end

      def terminate(:corrupted_client, state) do
        Socket.reply(socket, NosLib.serialize(%ErrorMessage{reason: :corrupted_client}))
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

    crypto = Keyword.get(opts, :crypto, Crypto.Login)
    timeout = Keyword.get(opts, :timeout, 300_000)

    socket = %Socket{
      socket: socket,
      crypto: crypto,
      transport: transport,
      transport_pid: parent,
      timeout: timeout
    }

    module.loop(socket)
  end

  def __loop__(module, socket) do
    case Socket.recv(socket) do
      {:ok, packet} ->
        Logger.info(["PACKET ", packet])
        parse(module, socket, packet)

      {:error, reason} ->
        module.terminate(reason, socket)
    end
  end

  defp parse(module, socket, <<"NsTeST", packet::binary>>) do
    handle(module, socket, NosLib.deserialize(packet))
  end

  defp parse(module, socket, packet) do
    module.terminate(:bad_case, socket)
  end

  defp handle(module, socket, packet) do
    case {client_version?(packet.client_vsn),
          client_checksum?(packet.username, packet.client_hash)} do
      {false, _} ->
        module.terminate(:outdated_client, socket)

      {_, false} ->
        module.terminate(:corrupted_client, socket)

      {true, true} ->
        case module.connect(packet, socket) do
          {:ok, reply, socket} ->
            Socket.reply(socket, NosLib.serialize(reply))
            module.terminate(:normal, socket)

          {:error, reply} ->
            Socket.reply(socket, NosLib.serialize(%ErrorMessage{reason: reason}))
            Socket.close(socket)
            module.terminate(:shutdown, socket)
        end
    end
  end

  def __terminate__(_, socket) do
    Socket.close(socket)
    :ok
  end

  defp client_version?(version) do
    required_version = Application.fetch_env!(:gateway, :client_version)
    Version.match?(version, required_version)
  end

  defp client_checksum?(username, client_hash) do
    required_hash = Application.fetch_env!(:gateway, :client_hash)
    expected_hash = :crypto.hash(:md5, required_hash <> username) |> Base.encode16()
    expected_hash == client_hash
  end
end
