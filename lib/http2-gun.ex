defmodule HTTP2Gun do
  alias HTTP2Gun.Request

  def request(pid) do
    request_test = %Request{
      host: "example.org",
      method: "GET",
      port: 443,
      path: "/",
      headers: [],
      body: ""
      }
    GenServer.call(pid, request_test)
  end

  def request_new(pid) do
    request_test = %Request{
      host: "example.com",
      method: "GET",
      port: 443,
      path: "/",
      headers: [],
      body: ""
      }
    GenServer.call(pid, request_test)
  end
end
