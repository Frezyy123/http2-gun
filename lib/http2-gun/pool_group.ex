defmodule HTTP2Gun.PoolGroup do
  use GenServer
  alias HTTP2Gun.PoolGroup
  # hostname: {name, pid, conns}
  @default_hostname "example.org"
  defstruct [
    pools: %{}
  ]
  def start_link() do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolGroup, [])
    {:ok, pid}
  end

  defp via_tuple(name) do
    {:via, HTTP2Gun.Registry, {:pool_name, name}}
  end

  def init(_) do
    # default poolgroup
    {:ok, pid} = HTTP2Gun.PoolConn.start_link()
    init_map = Map.put(%{}, @default_hostname,
                      {@default_hostname, pid, 0})
    {:ok, %{%PoolGroup{} | pools: init_map}}
  end

  def create_pool(hostname, state) do
    # registry
    {:ok, pid} = HTTP2Gun.PoolConn.start_link()
    update_map = Map.put(state.pools, hostname,
    {hostname, pid, 0})
    {%{state | pools: update_map}, pid}
  end

  def handle_call(request, from, state) do
    hostname = request.host
    IO.puts("$$$$$$$$$$$$$$$$")
    {new_state, pool_pid} =
      case Map.fetch(state.pools, hostname) |> IO.inspect do
        {:ok, {_,pid,_}} ->
          {state, pid}
          :error -> create_pool(hostname, state)
        end
    pid = self()
    spawn_link(fn ->
      response = GenServer.call(pool_pid, {request, pid})
      GenServer.reply(from, response) end)
    {:noreply, new_state}
  end

  def handle_cast({pool_pid, conns_count}, state) do
    IO.puts("@@@@@@@@@@@@@@2")
    {pool_pid, conns_count, state.pools} |> IO.inspect
    map = Enum.map(state.pools,
      fn {name, {hostname, pid, _}} ->
        if (pid == pool_pid) do
          {name, {hostname, pid,
                  conns_count + 1}}
        end
      end) |>IO.inspect
    |> Enum.into(%{})
    IO.puts("*********************************************************************************************************")
    {:noreply, %{state | pools: map}} |> IO.inspect
  end
end
