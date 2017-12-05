defmodule Arango.Socket do
  @moduledoc false

  @default_timeout 5_000
  @message_type_authorization 1000
  @version 1

  def connect(opts) do
    host = Keyword.get(opts, :host) |> String.to_charlist()
    port = Keyword.get(opts, :port)
    username = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)
    socket_opts = Keyword.fetch!(opts, :socket_opts)

    auth = [@version, @message_type_authorization, "plain", username, password]
           |> VelocyPack.encode_to_iodata!()
           |> VelocyStream.pack()

    timeout = @default_timeout

    with {:ok, socket} <- :gen_tcp.connect(host, port, socket_opts),
        :ok <- :gen_tcp.send(socket, "VST/1.0\r\n\r\n"),
        :ok <- :gen_tcp.send(socket, auth),
        :ok <- :gen_tcp.recv(socket, 0) do
        #:ok <- :inet.setopts(socket, active: :once) do
        {:ok, socket}
    end
  end

end
