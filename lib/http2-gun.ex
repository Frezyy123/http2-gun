defmodule HTTP2Gun do
  alias HTTP2Gun.Request

  def request(pid) do
    request_test = %Request{
      method: :post,
      path: "/",
      headers: [],
      body: ""
      }
    GenServer.call(pid, request_test)
  end
end
