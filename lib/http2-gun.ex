defmodule HTTP2Gun do
  alias HTTP2Gun.Request

  def get(url, headers \\ [], opts \\ %{}) do
    request("GET", url, "", headers, opts)
  end

  def post(url, body, headers \\ [], opts \\ %{}) do
    request("POST", url, body, headers, opts)
  end

  def request(method, url, body, headers \\ [], opts \\ %{}) do
    case URI.parse(url) do
      %URI{
        scheme: _scheme,
        host: host,
        path: path,
        port: port,
        query: _query}  when is_binary(host)
        and is_integer(port) ->
          method =
            case method do
              :get -> "GET"
              :post -> "POST"
              :put -> "PUT"
              :delete -> "DELETE"
              s when is_binary(s) -> s
            end
          request = %Request{host: host,
                             method: method,
                             path: path,
                             headers: headers,
                             body: body,
                             opts: opts,
                             port: port}

          GenServer.call(HTTP2Gun.PoolGroup, request)
    _ ->
        {:error, "Error URI"}
    end
  end

  def request_test(pid) do
    request(:get, "http://eporner.com:443/", "", [{"content-type", "text/html; charset=UTF-8"}])
  end

  def request_test_new(pid) do
    request(:get, "http://en.wikipedia.org:443/", "")
  end
end
