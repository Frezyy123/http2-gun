defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: true
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  setup do

    {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    pids = Enum.map(1..1500, fn x -> pid end)

    Enum.map(1..10, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)
    Enum.map(1..10, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request_new(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)

  end
end
