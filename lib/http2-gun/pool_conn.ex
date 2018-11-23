defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker

  @max_requests 100
  @count 8
  defstruct [
    conn: %{}
  ]

  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid}
  end

  def init(_) do
    state = open_conn(%__MODULE__{conn: %{}}, @count) |> IO.inspect
    {:ok, state}
  end

  defp via_tuple(name) do
    name |> IO.inspect
    {:via, HTTP2Gun.Registry, {:conn_name, name}}
  end

  def handle_info({pid, :decrement}, state) do
    IO.puts("---> Handle info DECREMENT")
    next_conn = %{state | conn: state.conn |> Map.update!(pid, fn {x, name} -> {x - 1, name} end)}
    {:noreply, next_conn} |> IO.inspect
  end

  def handle_info(msg, state) do
    IO.puts("POOL")
    msg |> IO.inspect
    {:noreply, state}
  end

  defp open_conn(state, count) do
    pid_list = Enum.map(1..count, fn name -> {:ok, conn_pid} = Worker.start_link(
                            %{host: "example.com", port: 443, opts: []},
                            via_tuple(name))
                            {conn_pid, name}
                            end)
    conn_map = Enum.map(pid_list, fn {conn_pid, name} ->{conn_pid, name} end) |>
    Enum.reduce(%{}, fn {pid,name},acc -> Map.merge(acc, Map.put(%{}, pid, {0,name})) end) |> IO.inspect


    %{state | conn: conn_map}
  end

  def handle_call(request, from, state) do
    IO.puts("---> Handle call POOL")



    {new_pid, new_state} = if Enum.empty?(state.conn) do

    else {min_key, {min_value, _}} = Enum.to_list(state.conn)
                                  |> IO.inspect |> Enum.min_by(fn {_, {value, _}} -> value end)
      cond do
        min_value < @max_requests ->
          IO.puts("------> Even less than MAX_REQUESTS")
          {_, {_, last_name}} = Enum.to_list(state.conn)
          |> Enum.max_by(fn {_, {_, name}} -> name end)
          new_state =  %{state | conn: state.conn
                          |> Map.update!(min_key, fn {x, last_name} -> {x + 1, last_name} end)}
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

    pid = self()
    spawn_link(fn ->
      response = GenServer.call(new_pid,  {request, cancel_ref})
      send(pid, {new_pid, :decrement})
      # Process.sleep(1000)
      GenServer.reply(from, response)
    end)

    {:noreply,  new_state} |> IO.inspect
  end

  # def terminate(reason, state) do
  #   IO.puts("*****************************************************************************")
  #   state |> IO.inspect
  # end
end
