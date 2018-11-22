defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: true
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.ConnectionWorker.Request
  setup do

    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolConn, [])
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    HTTP2Gun.request(pid)
    HTTP2Gun.request(pid)
    HTTP2Gun.request(pid)
  end

end
