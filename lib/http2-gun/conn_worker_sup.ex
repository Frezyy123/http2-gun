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
    IO.puts("Start_link ConnWorkerSup")
    {:ok, pid} = DynamicSupervisor.start_link(__MODULE__, :ok, name: name_pid)
    pid |> IO.inspect
    {:ok, pid}
  end

  def init(_) do
    IO.puts("Init ConnWorkerSup")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # def add_child do
    # DynamicSupervisor.start_child(__MODULE__, {Project.Sup, []})
  # end

end
