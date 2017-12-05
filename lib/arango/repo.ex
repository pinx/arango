defmodule Arango.Repo do
  @moduledoc false

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [
            opts: opts
          ] do

      {otp_app, config} = Arango.Repo.Supervisor.compile_config(__MODULE__, opts)
      @otp_app otp_app
      @config  config

      def config do
        {:ok, config} = Arango.Repo.Supervisor.runtime_config(:dry_run, __MODULE__, @otp_app, [])
        config
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker
        }
      end

      def start_link(opts \\ []) do
        Arango.Connection.start_link(opts)
      end

      def stop(conn, timeout \\ 5000) do
        Arango.Connection.stop(conn, :normal, timeout)
      end

      def all(queryable, opts \\ []) do
        #TODO: run query
      end
    end
  end
end