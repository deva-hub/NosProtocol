defmodule NosProtocol.Conn do
  @moduledoc """
  This module provides a data structure that represents an NosTale socket
  connection to a given server. The connection is represented as an opaque
  struct `%NosProtocol.Conn{}`. The connection is a data structure and is not
  backed by a process, and all the connection handling happens in the
  process that creates the struct.
  """

  defstruct socket: nil,
            transport: nil,
            encoder: nil,
            private: %{},
            assigns: %{},
            state: :open

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          encoder: module,
          private: map,
          assigns: map,
          state: atom
        }

  @spec assign(t, any, any) :: t
  def assign(%__MODULE__{assigns: assigns} = conn, key, value)
      when is_atom(key) do
    %{conn | assigns: Map.put(assigns, key, value)}
  end

  @spec merge_assigns(t, keyword) :: t
  def merge_assigns(%__MODULE__{assigns: assigns} = conn, keyword)
      when is_list(keyword) do
    %{conn | assigns: Enum.into(keyword, assigns)}
  end

  @spec put_private(t, any, any) :: t
  def put_private(%__MODULE__{private: private} = conn, key, value)
      when is_atom(key) do
    %{conn | private: Map.put(private, key, value)}
  end

  @spec merge_private(t, keyword) :: t
  def merge_private(%__MODULE__{private: private} = conn, keyword)
      when is_list(keyword) do
    %{conn | private: Enum.into(keyword, private)}
  end

  @spec put_state(t, atom) :: t
  def put_state(%__MODULE__{} = conn, state)
      when is_atom(state) do
    %{conn | state: state}
  end

  @spec render(t, module, any, keyword) :: t
  def render(conn, encoder, template, param) do
    param = Enum.into(param, %{})

    Enum.reduce(
      encoder.render(template, param),
      conn,
      &send_packet(&2, &1)
    )
  end

  @spec send_packet(t, keyword) :: t
  def send_packet(conn, data) do
    data = conn.encoder.encode(data)

    case conn.transport.send(conn.socket, data) do
      :ok ->
        conn

      {:error, :closed} ->
        raise """
        Can't send data to a closed socket.
        """
    end
  end

  @spec peer_addr(t) :: {:inet.ip_address(), :inet.port_number()}
  def peer_addr(conn) do
    case :inet.peername(conn.socket) do
      {:ok, {addr, port}} ->
        {addr, port}

      {:error, reason} ->
        raise """
        Unsupported descriptor type, got: #{inspect(reason)}
        """
    end
  end
end
