defmodule NosProtocol do
  def child_spec(opts) do
    unless protocol = opts[:protocol] do
      raise ArgumentError, "missing :protocol option on use NosProtocol"
    end

    protocol_options = Keyword.get(opts, :protocol_options, [])
    transport = Keyword.get(opts, :transport, :ranch_tcp)
    transport_options = Keyword.get(opts, :transport_options, port: 4123)

    ref = Keyword.get(opts, :ref) || build_ref(protocol, transport)

    :ranch.child_spec(ref, transport, transport_options, protocol, protocol_options)
  end

  def build_ref(protocol, :ranch_tcp) do
    Module.concat(protocol, TCP)
  end

  def build_ref(protocol, :ranch_ssl) do
    Module.concat(protocol, SSL)
  end
end
