defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: true
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  setup do

    {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    pids = Enum.map(1..101, fn x -> pid end)

    Enum.map(1..1, fn x ->
    pids
      |> Enum.map( &(Task.async(fn  -> HTTP2Gun.request(&1) end)))
      |> Enum.map(&(Task.await(&1)))
       end)
  end


  # test "pool_conn", %{pid: pid} do
  #   state = GenServer.call(pid, {:test})
  #   pid_conn = Enum.random(state.conn) |> IO.inspect

  #   assert {pid_conn, :decrement} == send(pid, {pid, :decrement})
  #   request = %Request{method: "POST", path: "/", headers: [], body: %{}, opts: []}
  #   assert 1 == GenServer.call(pid, request)
  # end


end
