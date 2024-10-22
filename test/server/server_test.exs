defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: false
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  alias HTTP2Gun.Response

  import Mock

  def request_test(_pid) do
    HTTP2Gun.request(:get, "http://eporner.com:443/", "", [{"content-type", "text/html; charset=UTF-8"}])
  end

  def request_test_new(_pid) do
    HTTP2Gun.request(:get, "http://en.wikipedia.org:443/", "")
  end

  setup do
    pid = Process.whereis(HTTP2Gun.PoolGroup)
    %{pid: pid}
  end

  test "restriction_test", %{pid: pid} do
    # more than 100 in connection
    pids = Enum.map(1..100, fn _x -> pid end)
    Enum.each(1..20, fn _x ->
                      pids
                      |> Enum.map(&(Task.async(fn -> request_test(&1) end)))
                      |> Enum.map(fn x ->Task.await(x, 2000) end)
                      end)
  end

  # test "request interface" do
  #   # forming request test
  #   with_mock GenServer, [call: fn(_, request)-> request end] do
  #     assert %Request{host: "example.org",
  #                     method: "GET",
  #                     path: "/",
  #                     headers: [],
  #                     body: "",
  #                     opts: %{},
  #                     port: 443} = HTTP2Gun.request(:get, "http://example.org:443/", "")
  #     # convertation test
  #     %Request{method: method_get} = HTTP2Gun.request(:get, "http://example.org:443/", "")
  #     assert "GET" == method_get
  #     %Request{method: method_put} = HTTP2Gun.request(:put, "http://example.org:443/", "")
  #     assert "PUT" == method_put
  #   end
  # end

  # test "connection worker test", %{pid: pid} do
  #     assert {:ok, _pid} = HTTP2Gun.ConnectionWorker.start_link(%Worker{pool_conn_pid: self(), host: "example.org", port: 443, opts: []})
  #     ref = :erlang.make_ref()
  #     # init test
  #     assert {:ok, init_state} = Worker.init(%{pool_conn_pid: self(), host: "example.org", port: 443, opts: []})
  #     {:ok, state} = Worker.init(init_state)
  #     from = {ref, self()}
  #     # streams and cancels not empty
  #     {:noreply, %Worker{streams: streams, cancels: cancels}} =
  #                                             Worker.handle_cast({%Request{method: "GET", path: "/", body: ""}, {pid, :erlang.make_ref()}}, state)
  #     assert not (Enum.empty?(streams) and Enum.empty?(cancels))
  #     # need to rewrite
  #     with_mock GenServer, [reply: fn(_,_) -> :ok end,
  #                           cast: fn(_, _) -> :ok end] do
  #       # should return the same
  #       assert {:noreply, state} == Worker.handle_info({:timeout, from, ref}, state)
  #       # # should delete cancels map and streams map and return the same state
  #       assert {:noreply, state} == Worker.handle_info({:timeout, from, ref}, %{state | cancels: Map.put(%{},ref, ref),
  #       streams: Map.put(%{}, ref, {{ref, self()}, %Response{}, ref, ref, from})})
  #       # stub, so nothing to test
  #       assert {:noreply, %Worker{}} = Worker.handle_info({:gun_error, "_", "_", "_"}, state)
  #       with_mock Map, [get: fn(_,_) -> {{ref, self()}, %Response{}, ref, ref, from} end] do
  #           #header check, should return response in streams
  #           headers = ["header:values"]
  #           assert {:noreply, response_state} = Worker.handle_info({:gun_response, self(), ref,
  #             :nofin, 200, headers}, init_state)
  #           {_,response, _, _, _} = response_state.streams |> Map.values |> hd
  #           assert response.headers == headers
  #           assert response.status_code == 200
  #           data = "hereisdata"
  #           assert {:noreply, data_state} = Worker.handle_info({:gun_data, self(), ref, :nofin, data}, state)
  #           {_,response, _, _, _} = data_state.streams |> Map.values |> hd
  #           assert response.body == data
  #       end
  #     end
  #     assert {:noreply, gunup_state} = Worker.handle_info({:gun_up, self(), :http2}, state)
  #     assert  nil != gunup_state.gun_pid
  # end

  # test "pool_conn handle_cast() test" do
  #   #start_link PoolCoon
  #   assert {:ok, pid} = HTTP2Gun.PoolConn.start_link(1)
  #   #add stream to connection from state
  #   state = %HTTP2Gun.PoolConn{
  #                             conn: %{
  #                               self() => {1, 1},
  #                               self() => {0, 2},
  #                               self() => {0, 3},
  #                               self() => {0, 4}
  #                             },
  #                             max_connections: 50,
  #                             max_requests: 50,
  #                             supervisor_pid: pid,
  #                             warming_up_count: 4
  #                           }
  #   {key, {_streams, conn_name}} = state.conn
  #                                   |> Map.to_list()
  #                                   |> hd
  #   update_state = state.conn
  #                   |> Map.update!(key, fn _current_value ->
  #                                       {1, conn_name} end)
  #   new_state = %{state | conn: update_state}
  #   assert {:noreply, new_state} == HTTP2Gun.PoolConn.handle_cast({%Request{host: "example.com",
  #                                                                         method: "GET",
  #                                                                         path: "/",
  #                                                                         headers: [],
  #                                                                         body: "",
  #                                                                         opts: %{}},
  #                                                                 self(), pid}, state)
  #   #add new connection, when all connection is filled
  #   update_state = %{state | conn: state.conn
  #                     |> Enum.map(fn {key, {_streams, conn_name}} ->
  #                                   {key, {50, conn_name}} end)
  #                     |> Enum.into(%{})}
  #   test_state = %{state | conn: update_state.conn
  #                               |> Map.put(:c.pid(0,209,0), {1, conn_name + 1})
  #                     }
  #   with_mock DynamicSupervisor, [start_child: fn _x, _y -> {:ok, :c.pid(0,209,0)} end] do
  #         {:noreply, res_state} = HTTP2Gun.PoolConn.handle_cast({%Request{host: "example.com",
  #                                                                   method: "GET",
  #                                                                   path: "/",
  #                                                                   headers: [],
  #                                                                   body: "",
  #                                                                   opts: %{}},
  #                                                           self(), pid}, update_state)
  #       assert test_state == %{state | conn: res_state.conn}
  #   end
  # end

  # test "pool_group handle_cast() test" do
  #   #add new pool to pools from state
  #   {:ok, state} = HTTP2Gun.PoolGroup.init(1)
  #   new_state = %{state | pools: state.pools
  #                           |> Map.put("example.com", {"example.com", '#PID<0.209.0>', 0})
  #                           |> Map.keys}
  #   {:noreply, res_state} = HTTP2Gun.PoolGroup.handle_call(%Request{host: "example.com",
  #                                                                         method: "GET",
  #                                                                         path: "/",
  #                                                                         headers: [],
  #                                                                         body: "",
  #                                                                         opts: %{}}, self(),
  #                                                                         state)
  #   assert new_state == %{state | pools: res_state.pools
  #                       |> Map.keys}
  # end
end
