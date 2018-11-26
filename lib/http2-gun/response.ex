defmodule HTTP2Gun.Response do
  defstruct [
    :request_url,
    :status_code,
    :headers,
    :body
  ]
end
