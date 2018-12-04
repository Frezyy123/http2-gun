defmodule HTTP2Gun.Application do
  use Application
  use DynamicSupervisor

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: HTTP2Gun.PoolConn},
      {DynamicSupervisor, strategy: :one_for_one, name: HTTP2Gun.Connection},
      %{id: PoolGroups,
        start: {HTTP2Gun.PoolGroup, :start_link, []},
        type: :supervisor
      }
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
