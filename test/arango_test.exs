defmodule ArangoTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Arango.Error
  alias Arango.ConnectionError
  alias Arango.TestHelpers

  @host TestHelpers.test_host()
  @port TestHelpers.test_port()

  setup_all do
    :ok
  end

  setup context do
    if context[:no_setup] do
      {:ok, %{}}
    else
      {:ok, conn} = Arango.start_link(host: @host, port: @port)
      {:ok, %{conn: conn}}
    end
  end

  @tag :no_setup
  test "start_link/2: specifying a database" do
    {:ok, c} = Arango.start_link(host: @host, port: @port, database: "test")
    assert Arango.command(c, "FROM doc in documents RETURN doc") == {:ok, "OK"}
#
#    # Let's check we didn't write to the default database (which is 0).
#    {:ok, c} = Redix.start_link(host: @host, port: @port)
#    assert Redix.command(c, ~w(GET my_key)) == {:ok, nil}
  end

end
