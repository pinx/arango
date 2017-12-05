defmodule Arango.Protocol do

  @version 1
  @message_type_request 1

  def pack(%Arango.Command{body: nil} = command) do
    command
    |> header()
    |> VelocyPack.encode_to_iodata!()
    |> VelocyStream.pack
  end
  def pack(%Arango.Command{} = command) do
    [
      command
      |> header()
      |> VelocyPack.encode_to_iodata!(),
      command.body
      |> VelocyPack.encode_to_iodata!()
    ]
    |> VelocyStream.pack
  end

  def parse(data)
  def parse(""), do: {:ok, nil, ""}
  def parse(data) do
    {message, 0} = VelocyPack.unpack(data)
    with {:ok, header, tail} <- VelocyPack.decode(message),
         {:ok, body, ""} = Velocypack.decode(tail) do
      {:ok, Result.from_response(header, body)}
    end
   end

  defp header(%Arango.Command{} = command) do
    [
      @version,
      @message_type_request,
      command.database,
      request_type(command.method),
      command.path,
      command.params,
      command.meta
    ]
  end

  defp request_type(:delete), do: 0
  defp request_type(:get), do: 1
  defp request_type(:post), do: 2
  defp request_type(:put), do: 3
  defp request_type(:head), do: 4
  defp request_type(:patch), do: 5
  defp request_type(:options), do: 6
end
