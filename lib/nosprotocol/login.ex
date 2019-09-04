defmodule NosProtocol.Login do
  @moduledoc """
  Processless NosTale client for the Login protocol.
  """
  alias NosProtocol.Conn

  @type option :: {:crypto, module}
  @type options :: [option]

  @spec open(:inet.socket(), module, options) :: {:ok, Conn.t()} | {:error, term}
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
        {:error, {:socket_error, reason}}
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
        {:error, Conn.put_state(conn, :closed), reason}
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

  def stream(_conn, _message), do: :unknown

  defp handle_data(conn, data) do
    packet = String.split(conn.crypto.decrypt(data))
    {:ok, conn, [{:packet, packet}]}
  end

  defp handle_close(conn) do
    {:ok, Conn.put_state(conn, :closed), [:done]}
  end

  defp handle_error(conn, error) do
    {:error, Conn.put_state(conn, :closed), error, []}
  end
end
