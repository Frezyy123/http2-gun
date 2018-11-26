defmodule HTTP2Gun.Request do
  defstruct [
    :host,
    :method,
    :port,
    :path,
    :headers,
    :body,
    :opts
  ]
end
