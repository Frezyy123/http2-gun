defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: false
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  import Mock

  setup do

    {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    pids = Enum.map(1..1500, fn x -> pid end)

    Enum.map(1..10, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request_test(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)
    Enum.map(1..10, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request_test_new(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)

  end
end
