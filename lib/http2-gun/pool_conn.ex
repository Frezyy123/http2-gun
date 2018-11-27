defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker
  @max_connections 5
  defstruct [
    :max_requests,
    :warming_up_count,
    conn: %{}
  ]

  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid}
  end

  def init(_) do
    app_env = Application.get_all_env(:http2_gun)
              |> Enum.into(%{})
    max_requests = app_env |> Map.get(:max_requests)
    warming_up_count = app_env |> Map.get(:warming_up_count)
    default_hostname = app_env |> Map.get(:default_hostname)
    default_port = app_env |> Map.get(:default_port)
    state = open_conn(%__MODULE__{conn: %{}}, warming_up_count,
                      default_hostname, default_port)
    {:ok, %{state |
            max_requests: max_requests, warming_up_count: warming_up_count}}
  end

  defp via_tuple(name) do
    name |> IO.inspect
    {:via, HTTP2Gun.Registry,
           {:conn_name, name}}
  end

  def handle_info({pid, :decrement}, state) do
    IO.puts("---> Handle info DECREMENT")
    next_conn = %{state | conn: state.conn
                  |> Map.update!(pid,
                    fn {x, name} ->
                      {x - 1, name} end)}
    {:noreply, next_conn} |> IO.inspect
  end

  # def handle_info(msg, state) do
  #   IO.puts("POOL")
  #   msg |> IO.inspect
  #   {:noreply, state}
  # end

  defp open_conn(state, count, host, port) do
    pid_list = Enum.map(1..count,
                fn name ->
                  {:ok, conn_pid} = Worker.start_link(%{host: host, port: port,
                                                        opts: []})
                  {conn_pid, name} end)

    conn_map = Enum.map(pid_list,
                 fn {conn_pid, name} ->
                   {conn_pid, name} end)
               |> Enum.reduce(%{},
                 fn {pid, name}, acc ->
                   Map.merge(acc, Map.put(%{},
                             pid, {0, name})) end)
               |> IO.inspect
    %{state | conn: conn_map}
  end

  def handle_call({request, pid}, from, state) do
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
          if (Enum.count(state.conn) < @max_connections) do
            IO.puts("------> Start new CONNECTION")
            GenServer.cast(pid, {self(),
                          Enum.count(state.conn), request.host})
            {_, {_, last_name}} = Enum.to_list(state.conn)
                                  |> Enum.max_by(fn {_, {_, name}} ->
                                                  name end)
            {:ok, conn_pid} = Worker.start_link(%{host: request.host,
                                                  port: request.port, opts: []}
                                                  )
            new_state = %{state | conn: state.conn
                          |> Map.put(conn_pid, {1, last_name + 1})}
            {conn_pid, new_state}
          else
            {nil, state}
          end
      end

    pid = self()
    case new_pid do
      nil -> GenServer.reply(from, "error")
      _ ->
        spawn_link(fn ->
          response = GenServer.call(new_pid, request)
          send(pid, {new_pid, :decrement})
          GenServer.reply(from, response) end)
    end

    {:noreply,  new_state} |> IO.inspect
  end
end
