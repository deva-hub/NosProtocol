defmodule NosProtocol.Conn do
  defstruct socket: nil,
            transport: nil,
            crypto: nil,
            private: %{},
            assigns: %{},
            state: :open

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          crypto: module,
          private: map,
          assigns: map,
          state: atom
        }

  def assign(%__MODULE__{assigns: assigns} = conn, key, value) when is_atom(key) do
    %{conn | assigns: Map.put(assigns, key, value)}
  end

  def merge_assigns(%__MODULE__{assigns: assigns} = conn, keyword) when is_list(keyword) do
    %{conn | assigns: Enum.into(keyword, assigns)}
  end

  def put_private(%__MODULE__{private: private} = conn, key, value) when is_atom(key) do
    %{conn | private: Map.put(private, key, value)}
  end

  def merge_private(%__MODULE__{private: private} = conn, keyword) when is_list(keyword) do
    %{conn | private: Enum.into(keyword, private)}
  end

  def put_state(%__MODULE__{} = conn, state) when is_atom(state) do
    %{conn | state: state}
  end

  def render(conn, serializer, template, param) do
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
        {stringify_addr(addr), port}

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
