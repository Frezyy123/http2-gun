defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: true
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.ConnectionWorker.Request
  setup do

    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolConn, [])
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    pids = Enum.map(1..360, fn x -> pid end) |> IO.inspect
    pids
      |> Enum.map( &(Task.async(fn  -> HTTP2Gun.request(&1) end)))
      |> Enum.map(&(Task.await(&1)))
      |> IO.inspect
  end

end
