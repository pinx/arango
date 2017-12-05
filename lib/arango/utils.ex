defmodule Arango.Utils do
  @moduledoc false

  @socket_opts [packet: :raw, mode: :binary, active: false]

  @arangodb_opts [:host, :port, :username, :password, :database]
  @arangodb_default_opts [
    host: "localhost",
    port: 8529,
    username: "root",
    password: "arango"
  ]

  @log_default_opts [
    disconnection: :error,
    failed_connection: :error,
    reconnection: :info
  ]

  @arango_behaviour_opts [
    :socket_opts,
    :sync_connect,
    :backoff_initial,
    :backoff_max,
    :log,
    :exit_on_disconnection
  ]
  @arango_default_behaviour_opts [
    socket_opts: @socket_opts,
    sync_connect: false,
    backoff_initial: 500,
    backoff_max: 30000,
    log: @log_default_opts,
    exit_on_disconnection: false
  ]

  def sanitize_starting_opts(arangodb_opts, other_opts)
      when is_list(arangodb_opts) and is_list(other_opts) do

    # `connection_opts` are the opts to be passed to `Connection.start_link/3`.
    # `redix_behaviour_opts` are the other options to tweak the behaviour of
    # Redix (e.g., the backoff time).
    {arango_behaviour_opts, connection_opts} = Keyword.split(other_opts, @arango_behaviour_opts)

    arangodb_opts = Keyword.merge(@arangodb_default_opts, arangodb_opts)
    arango_behaviour_opts = Keyword.merge(@arango_default_behaviour_opts, arango_behaviour_opts)

    arango_behaviour_opts =
      Keyword.update!(arango_behaviour_opts, :log, fn log_opts ->
        unless Keyword.keyword?(log_opts) do
          raise ArgumentError,
                "the :log option must be a keyword list of {action, level}, " <>
                "got: #{inspect(log_opts)}"
        end

        Keyword.merge(@log_default_opts, log_opts)
      end)

    arango_opts = Keyword.merge(arango_behaviour_opts, arangodb_opts)

    {arango_opts, connection_opts}
  end

  def format_host(%{opts: opts} = _state) do
    "#{opts[:host]}:#{opts[:port]}"
  end
end