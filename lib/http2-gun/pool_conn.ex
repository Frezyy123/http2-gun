defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.PoolConn
  alias HTTP2Gun.Error
  require Logger

  defstruct [
    :max_requests,
    :warming_up_count,
    :max_connections,
    :supervisor_pid,
    conn: %{}
  ]

  def start_link(args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args)
    Logger.info("start pool_conn #{inspect(pid)}")
    {:ok, pid}
  end

  def init(_args) do
    app_env = Application.get_all_env(:http2_gun)
              |> Enum.into(%{})
    max_requests = app_env |> Map.get(:max_requests)
    warming_up_count = app_env |> Map.get(:warming_up_count)
    default_hostname = app_env |> Map.get(:default_hostname)
    default_port = app_env |> Map.get(:default_port)
    max_connections = app_env |> Map.get(:max_connections)

    HTTP2Gun.ConnWorkerSup.start_link(self())
    send(self(), {:start_child, max_requests,
                  default_hostname, default_port,
                  warming_up_count, max_connections})

    {:ok, %PoolConn{}}
  end

  def handle_info({:start_child, max_requests,
                   default_hostname, default_port,
                   warming_up_count, max_connections},
                   state) do
    new_state = open_conn(state, warming_up_count,
                          default_hostname, default_port)

    {:noreply, %{new_state |
            max_requests: max_requests, warming_up_count: warming_up_count,
            max_connections: max_connections}}
  end

  def handle_info({:supervisor, sup_pid}, state) do

    {:noreply, %{state | supervisor_pid: sup_pid}}
  end

  def handle_info({pid, :decrement}, state) do
    Logger.info(":decrement #{inspect(pid)}")
    next_conn = %{state | conn: state.conn
                  |> Map.update!(pid,
                    fn {x, name} ->
                      {x - 1, name} end)}

    {:noreply, next_conn}
  end

  defp open_conn(state, count,
                 host, port) do
    Logger.info("warming up #{count} connections")
    pid_list = Enum.map(1..count,
                fn name ->
                  {:ok, conn_pid} = DynamicSupervisor.start_child(state.supervisor_pid, {HTTP2Gun.ConnectionWorker,
                                                                  %{host: host, port: port,
                                                                    opts: [], pool_conn_pid: self()}})
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

  def handle_cast({request, pid, pid_src},
                  state) do
      {min_key, {min_value, _}} = Enum.to_list(state.conn)
                                  |> Enum.min_by(fn {_, {value, _}} ->
                                                   value end)
      {new_pid, new_state} = cond do
        min_value < state.max_requests ->
          Logger.info("even less than MAX_REQUESTS")
          new_state =  %{state | conn: state.conn
                         |> Map.update!(min_key,
                              fn {x, name} ->
                                {x + 1, name} end)}

          {min_key, new_state}
        Enum.count(state.conn) < state.max_connections ->
          Logger.info("count connections less max number of connections. Create new connection")
          GenServer.cast(pid, {self(),
                        Enum.count(state.conn), request.host})
          {_, {_, last_name}} = Enum.to_list(state.conn)
                                |> Enum.max_by(fn {_, {_, name}} ->
                                                name end)
          {:ok, conn_pid} = DynamicSupervisor.start_child(state.supervisor_pid, {HTTP2Gun.ConnectionWorker,
                                                                                 %{host: request.host, port: request.port,
                                                                                   opts: [], pool_conn_pid: self()}})
          new_state = %{state | conn: state.conn
                        |> Map.put(conn_pid, {1, last_name + 1})}
          {conn_pid, new_state}
        true ->
          {nil, state}
      end

    case new_pid do
      nil ->
        GenServer.reply(pid_src, {%Error{reason: "LIMIT OF CONNECTION",
                                  source: __MODULE__}})
        Logger.info("limit of connections")
      _ ->
        GenServer.cast(new_pid, {request, pid_src})
        send(self(), {new_pid, :decrement})
    end

    {:noreply, new_state} |> IO.inspect
  end
end
