defmodule HTTP2Gun.PoolGroup do
  use GenServer
  alias HTTP2Gun.PoolGroup

  defstruct [
    :default_hostname,
    pools: %{}
  ]
  def start_link() do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolGroup, [])
    {:ok, pid}
  end

  def init(_) do
    # default poolgroup
    default_hostname = Application.get_env(:http2_gun, :default_hostname)
    {:ok, pid} = HTTP2Gun.PoolConn.start_link()
    init_map = Map.put(%{}, default_hostname,
                      {default_hostname, pid, 0})
    {:ok, %{%PoolGroup{} | pools: init_map, default_hostname: default_hostname}}
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
    {new_state, pool_pid} =
      case Map.fetch(state.pools, hostname) do
        {:ok, {_, pid, _}} ->
          {state, pid}
          :error -> create_pool(hostname, state)
        end
    pid = self()
    spawn_link(fn ->
      response = GenServer.call(pool_pid, {request, pid})
      GenServer.reply(from, response) end)
    {:noreply, new_state}
  end

  def handle_cast({pool_pid, conns_count, hostname}, state) do
    update_map = Map.update!(state.pools, hostname,
                             fn {_host, _pid, _count} ->
                               {hostname, pool_pid, conns_count + 1} end)
    {:noreply, %{state | pools: update_map}}
  end
end
