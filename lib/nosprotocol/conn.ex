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
            codec: nil,
            private: %{},
            assigns: %{},
            state: :open

  @type t :: %__MODULE__{
          socket: :inet.socket(),
          transport: module,
          codec: module,
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
end
