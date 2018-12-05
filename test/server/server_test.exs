defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: false
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  alias HTTP2Gun.Response

  import Mock

  setup do
    pid = Process.whereis(HTTP2Gun.PoolGroup) |> IO.inspect
    %{pid: pid}
  end

  test "restriction_test", %{pid: pid} do
    # more than 100 in connection
    pids = Enum.map(1..100, fn x -> pid end)
    result = Enum.each(1..50, fn x ->
                        pids
                        |> Enum.map(&(Task.async(fn ->  HTTP2Gun.request_test(&1)
                        HTTP2Gun.request_test_new(&1)
                          end)))
                        |> Enum.map(fn x ->Task.await(x) end)
                          end)
  end

  test "Request interface" do
    # forming request test
    with_mock GenServer, [call: fn(_,request)-> request end] do
      assert {%Request{host: "example.org",
                      method: "GET",
                      path: "/",
                      headers: [],
                      body: "",
                      opts: %{},
                      port: 443},_} =   HTTP2Gun.request(self(), :get, "http://example.org:443/", "")
      # convertation test
      {%Request{method: method_get}, _} = HTTP2Gun.request(self(), :get, "http://example.org:443/", "")
      assert "GET" == method_get
      {%Request{method: method_put}, _} = HTTP2Gun.request(self(), :put, "http://example.org:443/", "")
      assert "PUT" == method_put
    end
  end

  test "ConnectionWorkerTest", %{pid: pid} do
      assert {:ok, _pid} = HTTP2Gun.ConnectionWorker.start_link(%Worker{pool_conn_pid: self(), host: "example.org", port: 443, opts: []})

      ref = :erlang.make_ref()
      init_state = %Worker{host: "example.org", port: 443, opts: []}
      # init test
      assert {:ok, init_state} = Worker.init(%{pool_conn_pid: self(), host: "example.org", port: 443, opts: []})

      {:ok, state} = Worker.init(init_state)
      from = {ref, self()}
      # streams and cancels not empty
      {:noreply, %Worker{streams: streams, cancels: cancels}} =
                                              Worker.handle_cast({%Request{method: "GET", path: "/"}, pid}, state)
      assert not (Enum.empty?(streams) and Enum.empty?(cancels))
      # need to rewrite
      with_mock GenServer, [reply: fn(_,_) -> :ok end] do
        # should return the same
        assert {:noreply, state} == Worker.handle_info({:timeout, from, ref}, state)
        # # should delete cancels map and streams map and return the same state
        # assert {:noreply, state} == Worker.handle_info({:timeout, from, ref}, %{state | cancels: Map.put(%{},ref, ref),
        # streams: Map.put(%{}, ref, ref)})
        # stub, so nothing to test
        assert {:noreply, %Worker{}} = Worker.handle_info({:gun_error, "_", "_", "_"}, state)
        with_mock Map, [get: fn(_,_) -> {{ref, self()}, %Response{}, ref, ref} end] do


          # header check, should return response in streams
          # headers = ["header:values"]
          # assert {:noreply, response_state} = Worker.handle_info({:gun_response, self(), ref,
          #   :nofin, 200, headers}, init_state |> IO.inspect)
          # {_,response, _, _} = response_state.streams |> Map.values |> hd
          # assert response.headers == headers
          # assert response.status_code == 200


          # data = "hereisdata"
          # assert {:noreply, data_state} = Worker.handle_info({:gun_data, self(), ref, :nofin, data}, state)
          # {_,response, _, _} = data_state.streams |> Map.values |> hd
          # assert response.body == data

        end

      end

      assert {:noreply, gunup_state} = Worker.handle_info({:gun_up, self(), :http2}, state)
      assert  nil != gunup_state.gun_pid

  end


  test "PoolConn handle_cast() test" do
    #start_link PoolCoon
    assert {:ok, pid} = HTTP2Gun.PoolConn.start_link(self())
    #add stream to connection from state
    {:ok, state} = HTTP2Gun.PoolConn.init(1)
    make_ref = {self(), :erlang.make_ref()}
    {key, {_streams, conn_name}} = state.conn
                                   |> Map.to_list()
                                   |> hd
    update_state = state.conn
                   |> Map.update!(key, fn current_value ->
                                        {1, conn_name} end)
    new_state = %{state | conn: update_state}
    assert {:noreply, new_state} == HTTP2Gun.PoolConn.handle_cast({%Request{host: "example.com",
                                                                          method: "GET",
                                                                          path: "/",
                                                                          headers: [],
                                                                          body: "",
                                                                          opts: %{}},
                                                                  self(), pid}, state)
    #add new connection, when all connection is filled
    update_state = %{state | conn: state.conn
                      |> Enum.map(fn {key, {streams, conn_name}} ->
                                    {key, {100, conn_name}} end)
                      |> Enum.into(%{})}

    test_state = %{state | conn: update_state.conn
                                |> Map.put('#PID<0.209.0>', {0, conn_name + 1})
                                |> Map.keys
                                |> Enum.count}

    {:noreply, res_state} = HTTP2Gun.PoolConn.handle_cast({%Request{host: "example.com",
                                                                    method: "GET",
                                                                    path: "/",
                                                                    headers: [],
                                                                    body: "",
                                                                    opts: %{}},
                                                            self(), pid}, update_state)
    assert test_state == %{state | conn: res_state.conn
                                  |> Map.keys
                                  |> Enum.count}
  end

  test "PoolGroup handle_cast() test", %{pid: pid} do
    #start_link PoolGroup
    # assert {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    #add new pool to pools from state
    {:ok, state} = HTTP2Gun.PoolGroup.init(1)
    make_ref = self()
    new_state = %{state | pools: state.pools
                            |> Map.put("example.com", {"example.com", '#PID<0.209.0>', 0})
                            |> Map.keys}


    {:noreply, res_state} = HTTP2Gun.PoolGroup.handle_call({%Request{host: "example.com",
                                                                          method: "GET",
                                                                          path: "/",
                                                                          headers: [],
                                                                          body: "",
                                                                          opts: %{}}, pid}, self(),
                                                                          state)
    assert new_state == %{state | pools: res_state.pools
                        |> Map.keys}
  end

end
