defmodule HTTP2Gun do
  alias HTTP2Gun.Request

  def request(pid) do
    request_test = %Request{
      host: "example.org",
      method: "GET",
      path: "/",
      headers: [],
      body: ""
      }
    GenServer.call(pid, request_test)
  end
end
