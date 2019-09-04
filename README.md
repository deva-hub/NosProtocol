# NosProtocol

NosProtocol is a processless connection data structure and functions for the
NosTale SE protocol.

## Usage

To establish a open a connection, use `open/3`. This will  return an opaque data
structure that represents the connection to the server. The connection is a first
opened in the user land and the socket is internaly managed by the library in
**active mode** (with `active: :once`). This means that TCP/SSL messages will be
delivered to the process that started the connection.

The process that owns the connection is responsible for receiving the messages
(for example, a GenServer is responsible for defining `handle_info/2`). However,
`NosProtocol.Login` or `NosProtocol.World` are responsible for the packet
deserialisation with the `stream/2` function. This function takes the connection
and a term and returns `:unknown` if the term is not a TCP/SSL message belonging
to the connection. If the term *is* a message for the connection, then a response
and a new connection are returned. It's important to store the new returned
connection data structure over the old one since the connection is an immutable
data structure.
