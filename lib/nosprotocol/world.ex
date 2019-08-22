defmodule NosProtrocol.World do
  defstruct socket: nil,
            transport: nil,
            client_id: 0,
            packet_id: 0,
            mode: nil,
            state: :open

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          client_id: pos_integer,
          packet_id: pos_integer,
          mode: atom,
          state: atom
        }

  alias NosLib.{HandoffCrypto, WorldCrypto}

  def open(socket, transport) do
    conn = %__MODULE__{
      socket: socket,
      transport: transport
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
    packets = decode_packet(conn, data, [])

    case process_packets(conn, packets, responses) do
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

  defp decode_packet(%{state: :open} = conn, data, responses) do
    case HandoffCrypto.decrypt(data) do
      "" ->
        {:error, conn, {:invalid_packet, data}, responses}

      data ->
        [data]
    end
  end

  defp decode_packet(conn, data, responses) do
    WorldCrypto.decrypt(data, conn.client_id)
  end

  def process_packets(conn, packet, responses) do
    Enum.reduce_while(packet, {:ok, conn, responses}, fn
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
    {:ok, conn, [{:command, packet} | responses]}
  end
end
