defmodule HTTP2Gun.Application do
  use Application

  def start(_type, _args) do
    children = [
      %{id: PoolConnSup,
        start: {HTTP2Gun.PoolConnSup, :start_link, []},
      },
      %{id: PoolGroup,
        start: {HTTP2Gun.PoolGroup, :start_link, []},
      }
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
