defmodule NosLib.Login do
  defstruct socket: nil,
            transport: nil,
            client_version: "",
            state: :open

  @type state :: :open | :closed

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          client_version: String.t(),
          state: state
        }

  alias NosLib.LoginCrypto

  def open(socket, transport, options \\ []) do
    client_version = Keyword.fetch!(options, :client_version)

    conn = %__MODULE__{
      socket: socket,
      transport: transport,
      crypto: LoginCrypto,
      client_version: client_version,
      state: :open
    }

    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        {:ok, conn}

      {:error, reason} ->
        {:error, {:socket_error, reason}}
    end
  end

  def stream(%__MODULE__{socket: socket} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    case conn.transport.setopts(conn.socket, active: :once) do
      :ok ->
        handle_data(conn, data)

      {:error, reason} ->
        {:error, %{conn | state: :closed}, reason}
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
    {:ok, conn, [{:command, LoginCrypto.decrypt(data)} | responses]}
  end

  defp handle_close(conn) do
    {:ok, %{conn | state: :closed}, [:done]}
  end

  defp handle_error(conn, error) do
    {:error, %{conn | state: :closed}, error, []}
  end
end
