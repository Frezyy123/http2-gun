defmodule HTTP2Gun.ServerTest do
  use ExUnit.Case, async: false
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  alias HTTP2Gun.Response

  import Mock

  defp via_tuple(name) do
    {:via, HTTP2Gun.Registry,
           {:conn_name, name}}
  end

  setup do
    {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    {:ok, %{pid: pid}}
  end

  test "simple request", %{pid: pid} do
    pids = Enum.map(1..150, fn x -> pid end)
    Enum.map(1..2, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request_test(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)
    Enum.map(1..2, fn x ->
      pids
        |> Enum.map(&(Task.async(fn  -> HTTP2Gun.request_test_new(&1) end)))
        |> Enum.map(&(Task.await(&1))) end)
  end

  def request_test(pid) do
    HTTP2Gun.request(pid, :get, "http2://example.org:443/", "")
  end

  test "Request interface" do
    # forming request test
    with_mock GenServer, [call: fn(_,request)-> request end] do
      assert %Request{host: "example.org",
                      method: "GET",
                      path: "/",
                      headers: [],
                      body: "",
                      opts: %{},
                      port: 443} ==   HTTP2Gun.request(self(), :get, "http2://example.org:443/", "")
      # convertation test
      assert "GET" == HTTP2Gun.request(self(), :get, "http2://example.org:443/", "").method
      assert "PUT" == HTTP2Gun.request(self(), :put, "http2://example.org:443/", "").method
    end
  end

  test "ConnectionWorkerTest" do
      ref = :erlang.make_ref()
      init_state = %Worker{host: "example.org", port: 443, opts: []}
      # init test
      assert {:ok, init_state} = Worker.init(%{host: "example.org", port: 443, opts: []})

      {:ok, state} = Worker.init(init_state)
      from = {ref, self()}
      # streams and cancels not empty
      {:noreply, %Worker{streams: streams, cancels: cancels}} =
                                              Worker.handle_call(%Request{method: "GET", path: "/"}, from, state)
      assert not (Enum.empty?(streams) and Enum.empty?(cancels))
      # need to rewrite
      with_mock GenServer, [reply: fn(_,_) -> :ok end] do
        assert {:noreply, %Worker{}} = Worker.handle_info({:timeout, from, ref}, state)
        assert {:noreply, %Worker{}} = Worker.handle_info({:gun_error, "_", "_", "_"}, state)
        with_mock Map, [get: fn(_,_) -> {{ref, self()}, %Response{}, ref, ref} end] do
          assert {:noreply, %Worker{}} = Worker.handle_info({:gun_response,self(), ref,
          :fin, 200, []}, state)
          assert {:noreply, %Worker{}} = Worker.handle_info({:gun_data, self(), ref, :nofin, ""}, state)
        end
      end
      assert {:noreply, %Worker{}} = Worker.handle_info({:gun_up, self(), :http2}, state)
  end

  test "PoolConn handle_call() test" do
    assert {:ok, pid} = HTTP2Gun.PoolConn.start_link()

    {:ok, state} = HTTP2Gun.PoolConn.init(1) #|> IO.inspect
    make_fer = self()
    {key, {_streams, conn_name}} = state.conn
                                   |> Map.to_list()
                                   |> hd
    update_state = state.conn
                   |> Map.update!(key, fn current_value ->
                                        {1, conn_name} end)
    new_state = %{state | conn: update_state}
    assert {:noreply, new_state} == HTTP2Gun.PoolConn.handle_call({%Request{host: "example.com",
                                                                          method: "GET",
                                                                          path: "/",
                                                                          headers: [],
                                                                          body: "",
                                                                          opts: %{}},
                                                                  pid}, make_ref, state)
  end

  test "PoolGroup handle_call() test" do
    assert {:ok, pid} = HTTP2Gun.PoolGroup.start_link()
    {:ok, state} = HTTP2Gun.PoolGroup.init(1) |> IO.inspect
    make_fer = self()
    new_state = %{state | pools: state.pools
                            |> Map.put("example.com", {"example.com", '#PID<0.209.0>', 0})
                            |> Map.keys}
    {:noreply, res_state} = HTTP2Gun.PoolGroup.handle_call(%Request{host: "example.com",
                                                                          method: "GET",
                                                                          path: "/",
                                                                          headers: [],
                                                                          body: "",
                                                                          opts: %{}},
                                                                          make_ref, state)
    assert new_state == %{state | pools: res_state.pools
                        |> Map.keys}
  end
end
