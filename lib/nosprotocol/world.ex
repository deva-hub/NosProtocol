defmodule NosProtocol.World do
  defstruct socket: nil,
            transport: nil,
            session_crypto: nil,
            header_crypto: nil,
            client_id: 0,
            packet_id: 0,
            mode: nil,
            state: :open

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          session_crypto: module,
          header_crypto: module,
          client_id: pos_integer,
          packet_id: pos_integer,
          mode: atom,
          state: atom
        }

  def open(socket, transport, opts \\ []) do
    session_crypto = Keyword.fetch!(opts, :session_crypto)
    header_crypto = Keyword.fetch!(opts, :header_crypto)

    conn = %__MODULE__{
      socket: socket,
      transport: transport,
      session_crypto: session_crypto,
      header_crypto: header_crypto
    }

    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        {:ok, conn}

      {:error, reason} ->
        {:error, {:socket, reason}}
    end
  end

  def stream(%__MODULE__{socket: socket} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        handle_data(conn, data)

      {:error, reason} ->
        {:error, conn, reason}
    end
  end

  def stream(%__MODULE__{socket: socket} = conn, {tag, socket})
      when tag in [:tcp_closed, :ssl_closed] do
    handle_close(conn)
  end

  def stream(%__MODULE__{socket: socket} = conn, {tag, socket, reason})
      when tag in [:tcp_error, :ssl_error] do
    handle_error(conn, conn.transport.wrap_error(reason))
  end

  defp handle_data(conn, data) do
    packets = decode_packet(conn, data)

    case process_packets(conn, packets) do
      {:ok, conn, responses} ->
        {:ok, conn, Enum.reverse(responses)}

      {:error, conn, reason, responses} ->
        conn = %{conn | state: :closed}
        {:error, conn, reason, responses}
    end
  end

  defp handle_close(conn) do
    conn = %{conn | state: :closed}
    {:ok, conn, [:done]}
  end

  defp handle_error(conn, error) do
    conn = %{conn | state: :closed}
    {:error, conn, error, []}
  end

  defp decode_packet(%{state: :open} = conn, data) do
    case conn.header_crypto.decrypt(data) do
      "" ->
        raise ArgumentError

      data ->
        [data]
    end
  end

  defp decode_packet(conn, data) do
    conn.session_crypto.decrypt(data, conn.client_id)
  end

  def process_packets(conn, packets, responses \\ []) do
    Enum.reduce_while(packets, {:ok, conn, responses}, fn
      {id, packet}, {:ok, conn, responses} ->
        conn = %{conn | packet_id: id}
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
    conn = %{conn | client_id: packet, state: :identifier}
    {:ok, conn, [{:info, packet} | responses]}
  end

  def process_packet(%{state: :identifier} = conn, packet, responses) do
    conn = %{conn | state: :password}
    {:ok, conn, [{:chunk, {conn.packet_id, packet}} | responses]}
  end

  def process_packet(%{state: :password} = conn, packet, responses) do
    conn = %{conn | state: :world}
    {:ok, conn, [{:chunk, {conn.packet_id, packet}} | responses]}
  end

  def process_packet(conn, packet, responses) do
    {:ok, conn, [{:packet, packet} | responses]}
  end
end
