defmodule Arango.Connection do
  @moduledoc false

  use Connection

  alias Arango.ConnectionError
  alias Arango.Protocol
  alias Arango.Socket
  alias Arango.Utils
  alias Arango.Connection.Receiver
  alias Arango.Connection.Queue

  require Logger

  defstruct socket: nil,
            opts: nil,
            receiver: nil,
            queue: nil,
            backoff_current: nil

  @backoff_exponent 1.5

  @spec start_link(Keyword.t(), Keyword.t()) :: GenServer.on_start()
  def start_link(arangodb_opts, other_opts \\ []) do
    {arango_opts, connection_opts} = Utils.sanitize_starting_opts(arangodb_opts, other_opts)
    Connection.start_link(__MODULE__, arango_opts, connection_opts)
  end

  @spec stop(GenServer.server(), timeout) :: :ok
  def stop(conn, timeout) do
    GenServer.stop(conn, :normal, timeout)
  end

  def command(conn, command, timeout) do
    request_id = make_ref()
    try do
      {^request_id, resp} = Connection.call(conn, {:command, command, request_id}, timeout)
      resp
    catch
      :exit, {:timeout, {:gen_server, :call, [^conn | _]}} ->
        Connection.call(conn, {:timed_out, request_id})

        # We try to flush the response because it may have arrived before the
        # connection processed the :timed_out message. In case it arrived, we
        # notify the connection that it arrived (canceling the :timed_out
        # message).
        receive do
          {ref, {^request_id, _resp}} when is_reference(ref) ->
            Connection.call(conn, {:cancel_timed_out, request_id})
        after
          0 -> :ok
        end

        {:error, %ConnectionError{reason: :timeout}}
    end
  end

  # callbacks
  def init(opts) do
    state = %__MODULE__{opts: opts}
    {:connect, :init, state}
  end

  def connect(info, state) do
    case Socket.connect(state.opts) do
      {:ok, socket} ->
        state = %{state | socket: socket}
        {:ok, queue} = Queue.start_link()

        case start_receiver_and_hand_socket(state.socket, queue) do
          {:ok, receiver} ->
            # If this is a reconnection attempt, log that we successfully
            # reconnected.
            if info == :backoff do
              log(state, :reconnection, ["Reconnected to Arango (", Utils.format_host(state), ")"])
            end

            {:ok, %{state | queue: queue, receiver: receiver}}

          {:error, reason} ->
            log(state, :failed_connection, [
              "Failed to connect to Arango (",
              Utils.format_host(state),
              "): ",
              Exception.message(%ConnectionError{reason: reason})
            ])

            next_backoff =
              calc_next_backoff(
                state.backoff_current || state.opts[:backoff_initial],
                state.opts[:backoff_max]
              )

            if state.opts[:exit_on_disconnection] do
              {:stop, reason, state}
            else
              {:backoff, next_backoff, %{state | backoff_current: next_backoff}}
            end
        end

      {:error, reason} ->
        log(state, :failed_connection, [
          "Failed to connect to Redis (",
          Utils.format_host(state),
          "): ",
          Exception.message(%ConnectionError{reason: reason})
        ])

        next_backoff =
          calc_next_backoff(
            state.backoff_current || state.opts[:backoff_initial],
            state.opts[:backoff_max]
          )

        if state.opts[:exit_on_disconnection] do
          {:stop, reason, state}
        else
          {:backoff, next_backoff, %{state | backoff_current: next_backoff}}
        end

      {:stop, reason} ->
        # {:stop, error} may be returned by Redix.Utils.connect/1 in case
        # AUTH or SELECT fail (in that case, we don't want to try to reconnect
        # anyways).
        {:stop, reason, state}
    end
  end

  def handle_call({:command, _command, request_id}, _from, %{socket: nil} = state) do
    {:reply, {request_id, {:error, %ConnectionError{reason: :closed}}}, state}
  end

  def handle_call({:command, command, request_id}, from, %{socket: socket} = state) do
    :ok = Queue.enqueue(state.queue, {:command, request_id, from})

    # todo - use message id for VelocyStream
    data = Protocol.pack(command)

    case :gen_tcp.send(socket, data) do
      :ok ->
        {:noreply, state}
      {:error, reason} ->
        {:disconnect, {:error, %ConnectionError{reason: reason}}, state}
    end
  end

  # If the socket is nil, it means we're disconnected. We don't want to
  # communicate with the queue because it's not alive anymore.
  def handle_call({operation, _request_id}, _from, %{socket: nil} = state)
      when operation in [:timed_out, :cancel_timed_out] do
    {:reply, :ok, state}
  end

  def handle_call({:timed_out, request_id}, _from, state) do
    :ok = Queue.add_timed_out_request(state.queue, request_id)
    {:reply, :ok, state}
  end

  def handle_call({:cancel_timed_out, request_id}, _from, state) do
    :ok = Queue.cancel_timed_out_request(state.queue, request_id)
    {:reply, :ok, state}
  end

  def handle_info(msg, state)

  # Here and in the next handle_info/2 clause, we set the receiver to `nil`
  # because if we're receiving this message, it means the receiver died
  # peacefully by itself (so we don't want to communicate with it anymore, in
  # any way, before reconnecting and restarting it).
  def handle_info(
        {:receiver, pid, {:tcp_closed, socket}},
        %{receiver: pid, socket: socket} = state
      ) do
    state = %{state | receiver: nil}
    {:disconnect, {:error, %ConnectionError{reason: :tcp_closed}}, state}
  end

  def handle_info(
        {:receiver, pid, {:tcp_error, socket, reason}},
        %{receiver: pid, socket: socket} = state
      ) do
    state = %{state | receiver: nil}
    {:disconnect, {:error, %ConnectionError{reason: reason}}, state}
  end

  def terminate(reason, %{receiver: receiver, queue: queue} = _state) do
    if reason == :normal do
      :ok = GenServer.stop(receiver, :normal)
      :ok = GenServer.stop(queue, :normal)
    end
  end

  ## Helper functions

  defp sync_connect(state) do
    case Socket.connect(state.opts) do
      {:ok, socket} ->
        state = %{state | socket: socket}
        {:ok, queue} = Queue.start_link()

        case start_receiver_and_hand_socket(state.socket, queue) do
          {:ok, receiver} ->
            state = %{state | queue: queue, receiver: receiver}
            {:ok, state}

          {:error, reason} ->
            {:stop, %ConnectionError{reason: reason}}
        end

      {error_or_stop, reason} when error_or_stop in [:error, :stop] ->
        {:stop, %ConnectionError{reason: reason}}
    end
  end

  defp start_receiver_and_hand_socket(socket, queue) do
    {:ok, receiver} =
      Receiver.start_link(sender: self(), socket: socket, queue: queue)

    # We activate the socket after transferring control to the receiver
    # process, so that we don't get any :tcp_closed messages before
    # transferring control.
    with :ok <- :gen_tcp.controlling_process(socket, receiver),
         :ok <- :inet.setopts(socket, active: :once) do
      {:ok, receiver}
    end
  end

  defp flush_messages_from_receiver(%{receiver: receiver} = state) do
    receive do
      {:receiver, ^receiver, _msg} -> flush_messages_from_receiver(state)
    after
      0 -> :ok
    end
  end

  defp calc_next_backoff(backoff_current, backoff_max) do
    next_exponential_backoff = round(backoff_current * @backoff_exponent)

    if backoff_max == :infinity do
      next_exponential_backoff
    else
      min(next_exponential_backoff, backoff_max)
    end
  end

  defp log(state, action, message) do
    level =
      state.opts
      |> Keyword.fetch!(:log)
      |> Keyword.fetch!(action)

    Logger.log(level, message)
  end
end