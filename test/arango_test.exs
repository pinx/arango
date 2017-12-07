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
    {:ok, conn} = Arango.start_link(host: @host, port: @port, database: "test")
    command = %Arango.Command{
      database: "test",
      method: :post,
      path: "/_api/document/tests",
      params: %{},
      meta: %{},
      body: %{},
      opts: []
    }
    {:ok, %Arango.Result{} = result} = Arango.command(conn, command)
    assert !is_nil(result.body)
  end
end
