defmodule Arango do
  @moduledoc """
  Documentation for Arango.
  """

  @type command :: [binary]

  @default_timeout 5000

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, args},
      type: :worker
    }
  end

  @spec start_link(Keyword.t(), Keyword.t()) :: GenServer.on_start()
  def start_link(arango_opts \\ [], connection_opts \\ []) do
      Arango.Connection.start_link(arango_opts, connection_opts)
  end

  @spec stop(GenServer.server(), timeout) :: :ok
  def stop(conn, timeout \\ :infinity) do
    Arango.Connection.stop(conn, timeout)
  end
  def command(conn, %Arango.Command{} = command, opts \\ []) do
    Arango.Connection.command(conn, command, opts[:timeout] || @default_timeout)
  end
end
