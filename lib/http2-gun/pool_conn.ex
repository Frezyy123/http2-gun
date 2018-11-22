defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Connection, as: Connection

  @max_requests 150
  # conn - existing connections
  # conn: %{pid:{free: , state: (up or down)} }
  defstruct [
    conn: []
  ]
  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid}
  end

  def init(args) do
    {:ok, %__MODULE__{conn: []}}
  end

  # def handle_info(msg, state) do
  #   {:noreply, state}
  # end

  def handle_info({pid, :decrement}, state) do

    IO.puts("-------> Handle info DECREMENT")
    state |> IO.inspect
    conn = Enum.find(state.conn, fn x -> x.pid == pid end)
    next_conn = %{conn | count_requests: conn.count_requests - 1}
    {:noreply, %{state | conn: next_conn}} |> IO.inspect
  end

  def handle_call(request, from, state) do
    IO.puts("-------> Handle call POOL")
    state |> IO.inspect
    new_pid = if(Enum.empty?(state.conn)) do
      {:ok, conn_pid} = Worker.start_link(%{host: "example.com", port: 443, opts: []})
      conn_pid
    else
      min_conn = Enum.min_by(state.conn, fn x -> x.count_requests end)
      cond do
        min_conn.count_requests < @max_requests ->
          conn_pid = min_conn.pid
        true ->
          {:ok, conn_pid} = Worker.start_link(%{host: "example.com", port: 443, opts: []})
          conn_pid
      end
    end
    cancel_ref = :erlang.make_ref()

    current_connection = case(Enum.empty?(state.conn)) do
      true ->   %{state | conn: [state.conn ++ %Connection{pid: new_pid, count_requests: 1}]}
      _ ->
            conn = Enum.find(state.conn, fn x -> x.pid == new_pid end)
                  number = conn.count_requests + 1
            %{conn | count_requests: number}
    end |> IO.inspect

    response = spawn(GenServer, :call, [new_pid,  {request, cancel_ref}])

    send(self(), {new_pid, :decrement})

    GenServer.reply(from, response)

    # GenServer.call(pid,  {request, cancel_ref})
    {:noreply,  current_connection} |> IO.inspect
  end
end
