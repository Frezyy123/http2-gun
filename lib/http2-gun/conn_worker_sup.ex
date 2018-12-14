defmodule HTTP2Gun.ConnWorkerSup do
  use DynamicSupervisor

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(name_pid) do
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, :ok, name: name_pid)
    {:ok, pid}
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
