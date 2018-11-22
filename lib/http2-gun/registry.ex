defmodule HTTP2Gun.Registry do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def whereis_name(conn_name) do
    GenServer.call(:registry, {:whereis_name, conn_name})
  end

  def register_name(conn_name, pid) do
    GenServer.call(:registry, {:register_name, conn_name, pid})
  end

  def unregister_name(conn_name) do
    GenServer.cast(:registry, {:unregister_name, conn_name})
  end

  def send(conn_name, message) do
    case whereis_name(conn_name) do
      :undefined ->
        {:badarg, {conn_name, message}}
      pid ->
        Kernel.send(pid, message)
        pid
    end
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:whereis_name, conn_name}, _from, state) do
    {:reply, Map.get(state, conn_name, :undefined), state}
  end

  def handle_call({:register_name, conn_name, pid}, _from, state) do
    case Map.get(state, conn_name) do
      nil ->
        {:reply, :yes, Map.put(state, conn_name, pid)}
      _ ->
        {:reply, :no, state}
    end
  end

  def handle_cast({:unregister_name, conn_name}, state) do
    {:noreply, Map.delete(state, conn_name)}
  end
end
