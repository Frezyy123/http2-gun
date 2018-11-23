defmodule HTTP2Gun.Request do
  defstruct [
    :host,
    :method,
    :path,
    :headers,
    :body,
    :opts
  ]
end
