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
    IO.puts("Start_link PoolConnSup")
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    {:ok, pid}
  end

  def init(_) do
    IO.puts("Init PoolConnSup")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # def add_child do
    # DynamicSupervisor.start_child(__MODULE__, {Project.Sup, []})
  # end

end
