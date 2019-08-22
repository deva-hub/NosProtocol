defmodule NosProtrocol.Conn do
  def render_packet(conn, serializer, template, param \\ []) do
    param = Enum.into(param, %{})

    Enum.reduce(
      serializer.render(template, param),
      conn,
      &send_packet(&2, &1)
    )
  end

  def send_packet(conn, data) do
    data = conn.crypto.encrypt(data)

    case conn.transport.send(conn.socket, data) do
      :ok ->
        conn

      {:error, :closed} ->
        raise """
        Can't send data to a closed socket.
        """
    end
  end

  def peer_addr(conn) do
    case :inet.peername(conn.socket) do
      {:ok, {addr, port}} ->
        "#{stringify_addr(addr)}:#{port}"

      {:error, reason} ->
        raise """
        Unsupported descriptor type, got: #{inspect(reason)}
        """
    end
  end

  defp stringify_addr(addr) do
    addr
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
