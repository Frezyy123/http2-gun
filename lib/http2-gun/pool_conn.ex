defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker

  @max_requests 150

  defstruct [
    conn: %{}
  ]
  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid}
  end

  def init(_) do
    {:ok, %__MODULE__{conn: %{}}}
  end

  # def handle_info(msg, state) do
  #   {:noreply, state}
  # end

  defp via_tuple(name) do
    {:via, HTTP2Gun.Registry, {:conn_name, name}}
  end

  def handle_info({pid, :decrement}, state) do
    IO.puts("---> Handle info DECREMENT")
    next_conn = %{state | conn: state.conn |> Map.update!(pid, fn {x, name} -> {x - 1, name} end)}
    {:noreply, next_conn} |> IO.inspect
  end

  def handle_call(request, from, state) do
    IO.puts("---> Handle call POOL")
    {new_pid, new_state} =
      if(Enum.empty?(state.conn)) do
        IO.puts("------> State is EMPTY")
        name = 1
        {:ok, conn_pid} = Worker.start_link(
                            %{host: "example.com", port: 443, opts: []},
                            via_tuple(name))
        new_state =  %{state | conn: state.conn
                        |> Map.put(conn_pid, {1, name})}
        {conn_pid, new_state}
      else
        {min_key, {min_value, _}} = Enum.to_list(state.conn)
                                    |> Enum.min_by(fn {_, {value, _}} -> value end)
        cond do
          min_value < @max_requests ->
            IO.puts("------> Even less than MAX_REQUESTS")
            new_state =  %{state | conn: state.conn
                            |> Map.update!(min_key, fn {x, name} -> {x + 1, name} end)}
            {min_key, new_state}
          true ->
            IO.puts("------> Start new CONNECTION")
            {_, {_, last_name}} = Enum.to_list(state.conn)
                                  |> Enum.max_by(fn {_, {_, name}} -> name end)
            {:ok, conn_pid} = Worker.start_link(
                                %{host: "example.com", port: 443, opts: []},
                                via_tuple(last_name + 1 ))
            new_state = %{state | conn: state.conn
                            |> Map.put(conn_pid, {1, last_name + 1})}
            {conn_pid, new_state}
        end
      end
    cancel_ref = :erlang.make_ref()


    # current_connection = case(Enum.empty?(state.conn)) do
    #   true ->
    #         %{state | conn: state.conn |> Map.put(new_pid, 1)}
    #   _ ->
    #         %{state | conn: state.conn |> Map.update!(new_pid, fn x -> x + 1 end)}
    # end

    # response = spawn(GenServer, :call, [new_pid,  {request, cancel_ref}])
    response = spawn_link(GenServer, :call, [new_pid,  {request, cancel_ref}])
    send(self(), {new_pid, :decrement}) |> IO.inspect
    self() |> IO.inspect

    GenServer.reply(from, response)

    # GenServer.call(pid,  {request, cancel_ref})
    {:noreply,  new_state} |> IO.inspect
  end
end
