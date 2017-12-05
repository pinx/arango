ExUnit.start()

if Code.ensure_loaded?(ExUnitProperties) do
  Application.ensure_all_started(:stream_data)
end

host = System.get_env("ARANGO_TEST_HOST") || "localhost"
port = String.to_integer(System.get_env("ARANGO_TEST_PORT") || "8529")
user = System.get_env("ARANGO_USER") || "root"
password = System.get_env("ARANGO_PASSWORD") || "arango"

case :gen_tcp.connect(String.to_charlist(host), port, []) do
  {:ok, socket} ->
    :gen_tcp.close(socket)

  {:error, reason} ->
    Mix.raise("Cannot connect to Arango (http://#{host}:#{port}): #{:inet.format_error(reason)}")
end

defmodule Arango.TestHelpers do
  def test_host(), do: unquote(host)
  def test_port(), do: unquote(port)
end