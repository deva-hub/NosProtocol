defmodule NosProtocol.Login do
  @moduledoc """
  Processless NosTale client for the Login protocol.
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
      state: :open
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
        {:error, Conn.put_state(conn, :closed), reason}
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

  @spec send(t, keyword) :: :ok | {:error, any}
  def send(conn, data) do
    map = Enum.into(data, %{})
    iodata = conn.codec.encode(map)
    conn.transport.send(conn.socket, iodata)
  end

  defp handle_data(conn, data) do
    packet = String.split(conn.codec.encode(data))
    {:ok, conn, [{:packet, packet}]}
  end

  defp handle_close(conn) do
    {:ok, Conn.put_state(conn, :closed), [:done]}
  end

  defp handle_error(conn, error) do
    {:error, Conn.put_state(conn, :closed), error, []}
  end
end
