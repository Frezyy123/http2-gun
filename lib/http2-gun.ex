defmodule HTTP2Gun do
  alias HTTP2Gun.Request

  def get(url, headers \\ [], opts \\ %{}) do
    request("GET", url, "", headers, opts)
  end

  def post(url, body, headers \\ [], opts \\ %{}) do
    request("POST", url, body, headers, opts)
  end

  def get!(url, headers \\ [], opts \\ %{}) do
    request!("GET", url, "", headers, opts)
  end

  def post!(url, body, headers \\ [], opts \\ %{}) do
    request!("POST", url, body, headers, opts)
  end

  """
  :host,
    :method,
    :port,
    :path,
    :headers,
    :body,
    :opts
  """
  def request(pid, method, url, body, headers \\ [], opts \\ %{}) do

    case URI.parse(url)|> IO.inspect do
      %URI{
        scheme: scheme,
        host: host,
        path: path,
        port: port,
        query: query}  when is_binary(host) and is_integer(port) ->
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
        GenServer.call(pid, request)
    true ->
                {:error, "Error URI"}
    end

  end

  def request!(pid, method, url, body, headers \\ [], opts \\ %{}) do

    # GenServer.call(pid, request_test)
  end
  def request_test(pid) do
    request(pid, :get, "http://example.org:443/", "")
  end

  def request_test_new(pid) do
    request(pid, :get, "http://en.wikipedia.org:443/", "")
  end

end

