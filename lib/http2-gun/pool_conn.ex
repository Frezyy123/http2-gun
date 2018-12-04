defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Response
  alias HTTP2Gun.Error

  defstruct [
    :max_requests,
    :warming_up_count,
    :max_connections,
    :pool_group_pid,
    conn: %{}
  ]

  def start_link(pool_group_pid) do
    {:ok, pid} = GenServer.start_link(__MODULE__, pool_group_pid)
    {:ok, pid}
  end

  def init(pool_group_pid) do
    app_env = Application.get_all_env(:http2_gun)
              |> Enum.into(%{})
    max_requests = app_env |> Map.get(:max_requests)
    warming_up_count = app_env |> Map.get(:warming_up_count)
    default_hostname = app_env |> Map.get(:default_hostname)
    default_port = app_env |> Map.get(:default_port)
    max_connections = app_env |> Map.get(:max_connections)
    state = open_conn(%__MODULE__{conn: %{}}, warming_up_count,
                      default_hostname, default_port)
    {:ok, %{state |
            max_requests: max_requests, warming_up_count: warming_up_count,
            max_connections: max_connections, pool_group_pid: pool_group_pid}}
  end

  def handle_info({pid, :decrement}, state) do
    IO.puts("---> Handle info DECREMENT")
    next_conn = %{state | conn: state.conn
                  |> Map.update!(pid,
                    fn {x, name} ->
                      {x - 1, name} end)}
    {:noreply, next_conn}
  end

  defp open_conn(state, count, host, port) do
    pid_list = Enum.map(1..count,
                fn name ->
                  {:ok, conn_pid} = DynamicSupervisor.start_child(HTTP2Gun.Connection,
                  %{id: 5, start: {HTTP2Gun.ConnectionWorker, :start_link, [%{host: host, port: port,
                                                          opts: [], pool_conn_pid: self()}]}})
                  {conn_pid, name} end)
    conn_map = Enum.map(pid_list,
                 fn {conn_pid, name} ->
                   {conn_pid, name} end)
               |> Enum.reduce(%{},
                 fn {pid, name}, acc ->
                   Map.merge(acc, Map.put(%{},
                             pid, {0, name})) end)
    %{state | conn: conn_map}
  end

  def handle_cast({%Response{} = response, pid_src}, %__MODULE__{pool_group_pid: from_pid} = state) do
    GenServer.cast(from_pid, {response, pid_src})
    {:noreply, state}
  end

  def handle_cast(:timeout, %__MODULE__{pool_group_pid: from_pid} = state) do
    GenServer.cast(from_pid, %Error{reason: "GUN DOWN",
    source: __MODULE__})
    {:noreply, state}
  end

  def handle_cast({request, pid, pid_src}, state) do
    IO.puts("---> Handle call POOL")
      {min_key, {min_value, _}} = Enum.to_list(state.conn)
                                    |> Enum.min_by(fn {_, {value, _}} ->
                                                     value end)
      {new_pid, new_state} = cond do
        min_value < state.max_requests ->
          IO.puts("------> Even less than MAX_REQUESTS")
          {_, {_, last_name}} = Enum.to_list(state.conn)
                                |> Enum.max_by(fn {_, {_, name}} ->
                                                 name end)

          new_state =  %{state | conn: state.conn
                         |> Map.update!(min_key,
                              fn {x, last_name} ->
                                {x + 1, last_name} end)}
          {min_key, new_state}

        true ->
          if (Enum.count(state.conn) < state.max_connections) do
            IO.puts("------> Start new CONNECTION")
            GenServer.cast(pid, {self(),
                          Enum.count(state.conn), request.host})
            {_, {_, last_name}} = Enum.to_list(state.conn)
                                  |> Enum.max_by(fn {_, {_, name}} ->
                                                  name end)
            {:ok, conn_pid} = Worker.start_link(%{host: request.host,
                                                  port: request.port, opts: [], pool_conn_pid: self()}
                                                  )
            new_state = %{state | conn: state.conn
                          |> Map.put(conn_pid, {1, last_name + 1})}
            {conn_pid, new_state}
          else
            {nil, state}
          end
      end

    pid_self = self()
    case new_pid do
      nil -> GenServer.cast(pid, {%Error{reason: "GUN DOWN",
      source: __MODULE__}, pid_src})
      _ ->
        GenServer.cast(new_pid, {request, pid_src})
        send(pid_self, {new_pid, :decrement})
    end
    {:noreply, new_state} |> IO.inspect
  end
end
