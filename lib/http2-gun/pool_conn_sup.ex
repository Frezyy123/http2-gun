defmodule HTTP2Gun.PoolConnSup do
  use DynamicSupervisor

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link() do
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    {:ok, pid}
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
