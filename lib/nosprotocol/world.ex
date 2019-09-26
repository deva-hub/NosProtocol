defmodule NosProtocol.World do
  @moduledoc """
  Processless NosTale client for the World protocol.
  """
  alias NosProtocol.Conn

  @type option :: {:codec, module}
  @type options :: [option]

  @spec connect(:inet.socket(), module, options) ::
          {:ok, Conn.t()} | {:error, any}
  def connect(socket, transport, opts \\ []) do
    codec = Keyword.fetch!(opts, :codec)

    conn = %Conn{
      socket: socket,
      transport: transport,
      codec: codec,
      state: :auth
    }

    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        {:ok, conn}

      {:error, reason} ->
        {:error, {:socket, reason}}
    end
  end

  @type responses :: [binary]

  @spec stream(Conn.t(), {:tcp | :ssl, :inet.socket(), binary}) ::
          {:ok, Conn.t(), responses}
          | {:error, Conn.t(), term, responses}
  def stream(%Conn{socket: socket} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        handle_data(conn, data)

      {:error, reason} ->
        {:error, conn, reason, []}
    end
  end

  @spec stream(Conn.t(), {:tcp_closed | :ssl_closed, :inet.socket(), binary}) ::
          {:ok, Conn.t(), responses}
  def stream(%Conn{socket: socket} = conn, {tag, socket})
      when tag in [:tcp_closed, :ssl_closed] do
    handle_close(conn)
  end

  @spec stream(Conn.t(), {:tcp_error | :ssl_error, :inet.socket(), binary}) ::
          {:error, Conn.t(), term, responses}
  def stream(%Conn{socket: socket} = conn, {tag, socket, reason})
      when tag in [:tcp_error, :ssl_error] do
    handle_error(conn, conn.transport.wrap_error(reason))
  end

  @spec stream(Conn.t(), term) :: :unknown
  def stream(_conn, _message),
    do: :unknown

  defp handle_data(conn, data) do
    packets = decode_packet(conn, data)

    case process_packets(conn, packets) do
      {:ok, conn, responses} ->
        {:ok, conn, Enum.reverse(responses)}

      {:error, conn, reason, responses} ->
        conn = Conn.put_state(conn, :closed)
        {:error, conn, reason, responses}
    end
  end

  @spec send(t, keyword) :: :ok | {:error, any}
  def send(conn, data) do
    map = Enum.into(data, %{})
    iodata = conn.codec.encode(map)
    conn.transport.send(conn.socket, iodata)
  end

  defp handle_close(conn) do
    conn = Conn.put_state(conn, :closed)
    {:ok, conn, [:done]}
  end

  defp handle_error(conn, error) do
    conn = Conn.put_state(conn, :closed)
    {:error, conn, error, []}
  end

  defp decode_packet(%{state: :open} = conn, data) do
    case conn.codec.encode(data) do
      [] -> raise ArgumentError
      packets -> packets
    end
  end

  defp decode_packet(conn, data) do
    session_id = conn.private[:session_id]
    conn.codec.encode(data, session_id: session_id)
  end

  defp process_packets(conn, packets) do
    Enum.reduce(packets, {:ok, conn, []}, fn
      packet, {:ok, conn, responses} ->
        process_packet(conn, packet, responses)

      packet, {:error, conn, reason, responses} ->
        case process_packet(conn, packet, responses) do
          {:ok, conn, responses} ->
            {:error, conn, reason, responses}

          other ->
            other
        end
    end)
  end

  defp process_packet(conn, "0", responses),
    do: {:ok, conn, [:heartbeat | responses]}

  defp process_packet(%{state: :auth} = conn, session_id, responses) do
    conn = Conn.put_private(conn, :session_id, session_id)
    conn = Conn.put_state(conn, :open)
    {:ok, conn, [{:info, session_id} | responses]}
  end

  defp process_packet(%{state: :open} = conn, {packet_number, packet}, responses) do
    if conn.private[:packet_number] === packet_number + 1 do
      conn = Conn.put_private(conn, :packet_number, id)
      {:ok, conn, [{:packet, packet} | responses]}
    else
      conn = Conn.put_private(conn, :packet_number, id)
      {:error, conn, :unordered_packet, [{:packet, packet} | responses]}
    end
  end

  defp process_packet(%{state: :open} = conn, packet, responses),
    do: {:ok, conn, [{:packet, packet} | responses]}
end
