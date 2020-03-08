defmodule NosProtocol.Portal.Socket do
  defstruct [
    :socket,
    :crypto,
    :transport,
    :transport_pid,
    :timeout
  ]

  def recv(%__MODULE__{} = socket) do
    :ok = socket.transport.setopts(socket.socket, active: :once)
    {ok, closed, error} = socket.transport.messages()

    receive do
      {^ok, ^socket, data} ->
        {:ok, socket.crypto.decrypt(data)}

      {^error, ^socket, reason} ->
        {:error, {:socket_error, reason}}

      {^closed, ^socket} ->
        {:error, {:socket_error, :closed}}
    after
      socket.timeout ->
        {:error, :timeout}
    end
  end

  def send(%__MODULE__{} = socket, packet) do
    socket.transport.send(socket.socket, socket.crypto.encrypt(packet))
  end

  def close(%__MODULE__{} = socket) do
    socket.transport.close(socket.socket)
  end
end
