defmodule HTTP2Gun.PoolGroup do

  use GenServer
  alias HTTP2Gun.PoolGroup
  require Logger

  defstruct [
    :default_hostname,
    :interface_pid,
    pools: %{}
  ]

  def start_link() do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolGroup, [], name: HTTP2Gun.PoolGroup)
    Logger.info("start pool_group #{inspect(pid)}")

    {:ok, pid}
  end

  def init(_) do
    default_hostname = Application.get_env(:http2_gun, :default_hostname)
    {state, _pid} = create_pool(default_hostname, %PoolGroup{})

    {:ok, %{state | default_hostname: default_hostname}}
  end

  def create_pool(hostname, state) do
    Logger.info("create pool")
    {:ok, pid} = DynamicSupervisor.start_child(HTTP2Gun.PoolConnSup, {HTTP2Gun.PoolConn, []})
    update_map = Map.put(state.pools, hostname, {hostname, pid, 0})

    {%{state | pools: update_map}, pid}
  end

  def handle_call(request, from,
                  state) do
    hostname = request.host
    {new_state, pool_pid} =
      case Map.fetch(state.pools, hostname) do
        {:ok, {_, pid, _}} ->
          {state, pid}
        :error ->
          create_pool(hostname, state)
      end
    GenServer.cast(pool_pid, {request, self(), from})

    {:noreply, new_state}
  end

  def handle_cast({error_reason, pid_src},
                  state) do
    GenServer.reply(pid_src, error_reason)

    {:noreply, state}
  end

  def handle_cast({pool_pid, conns_count, hostname},
                  state) do
    update_map = Map.update!(state.pools, hostname,
                             fn {_host, _pid, _count} ->
                               {hostname, pool_pid, conns_count + 1} end)

    {:noreply, %{state | pools: update_map}}
  end
end
