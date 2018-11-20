defmodule HTTP2Gun.Request do
  defstruct [
    :method,
    :path,
    :headers,
    :body,
    :opts
  ]
end
