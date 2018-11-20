defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: true
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.ConnectionWorker.Request
  setup do

    {:ok, pid} = GenServer.start_link(HTTP2Gun.PoolConn, [])
    {:ok, %{pid: pid}}
  end




  # test "Call Worker " , %{pid: pid} do
  #   request_timeout = 5000
  #   cancel_ref = :erlang.make_ref()
  # request_test = %Request{
  #                           method: :post,
  #                           path: "/",
  #                           headers: [],
  #                           body: ""
  #                           }


  # worker = %Worker{host: "localhost",
  #                  port: 443,
  #                  opts: [],
  #                  gun_pid: nil,
  #                  gun_ref: nil,
  #                  m_mod: nil,
  #                  m_state: nil,
  #                  streams: %{},
  #                  cancels: %{}
  #                 }

  #    GenServer.call(pid,
  #    {request_test, cancel_ref},
  #    request_timeout) |> IO.inspect

  # end
  test "simple request", %{pid: pid} do
    HTTP2Gun.request(pid)
  end

end
