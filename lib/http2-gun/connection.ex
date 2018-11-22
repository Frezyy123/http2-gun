defmodule HTTP2Gun.Connection do
  defstruct [
    :pid,
    count_requests: 0
  ]
end
