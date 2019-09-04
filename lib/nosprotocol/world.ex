defmodule NosProtocol.World do
  @moduledoc """
  Processless NosTale client for the World protocol.
  """
  alias NosProtocol.Conn

  @type option :: {:crypto, module}
  @type options :: [option]

  @spec open(:inet.socket(), module, options) ::
          {:ok, Conn.t()}
          | {:error, term}
  def open(socket, transport, opts \\ []) do
    crypto = Keyword.fetch!(opts, :crypto)

    conn = %Conn{
      socket: socket,
      transport: transport,
      crypto: crypto,
      state: :open
    }

    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        {:ok, conn}

      {:error, reason} ->
        {:error, {:socket, reason}}
    end
  end

  @type packet :: binary
  @type packets :: [packet]

  @spec stream(Conn.t(), term) ::
          {:ok, Conn.t(), packets}
          | {:error, Conn.t(), term, packets}
          | :unknown
  def stream(conn, message)

  def stream(%Conn{socket: socket} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        handle_data(conn, data)

      {:error, reason} ->
        {:error, conn, reason, []}
    end
  end

  def stream(%Conn{socket: socket} = conn, {tag, socket})
      when tag in [:tcp_closed, :ssl_closed] do
    handle_close(conn)
  end

  def stream(%Conn{socket: socket} = conn, {tag, socket, reason})
      when tag in [:tcp_error, :ssl_error] do
    handle_error(conn, conn.transport.wrap_error(reason))
  end

  def stream(%Conn{socket: socket} = conn, _),
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

  defp handle_close(conn) do
    conn = Conn.put_state(conn, :closed)
    {:ok, conn, [:done]}
  end

  defp handle_error(conn, error) do
    conn = Conn.put_state(conn, :closed)
    {:error, conn, error, []}
  end

  defp decode_packet(%{state: :open} = conn, data) do
    case conn.crypto.decrypt(data) do
      "" ->
        raise ArgumentError

      data ->
        [data]
    end
  end

  defp decode_packet(conn, data) do
    session_id = conn.private[:session_id]

    data
    |> conn.crypto.decrypt(session_id: session_id)
    |> String.split()
  end

  def process_packets(conn, packets, responses \\ []) do
    Enum.reduce_while(packets, {:ok, conn, responses}, fn
      {id, packet}, {:ok, conn, responses} ->
        conn = Conn.put_private(conn, :packet_id, id)
        {:cont, process_packet(conn, packet, responses)}

      packet, {:ok, conn, responses} ->
        {:cont, process_packet(conn, packet, responses)}

      _data, {:error, conn, reason, responses} ->
        {:halt, {:error, conn, reason, responses}}
    end)
  end

  def process_packet(conn, "0", responses) do
    responses = [:heartbeat | responses]
    {:ok, conn, responses}
  end

  def process_packet(%{state: :open} = conn, packet, responses) do
    conn = Conn.put_private(conn, :session_id, packet)
    responses = [{:info, packet} | responses]
    {:ok, conn, responses}
  end

  def process_packet(%{state: :identifier} = conn, packet, responses) do
    conn = Conn.put_state(conn, :password)
    responses = [{:packet, packet} | responses]
    {:ok, conn, responses}
  end

  def process_packet(%{state: :password} = conn, packet, responses) do
    conn = Conn.put_state(conn, :world)
    responses = [{:packet, packet} | responses]
    {:ok, conn, responses}
  end

  def process_packet(%{state: :world} = conn, packet, responses) do
    responses = [{:packet, packet} | responses]
    {:ok, conn, responses}
  end
end
