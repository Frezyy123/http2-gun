defmodule HTTP2Gun.PoolConn do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  # conn - existing connections
  # conn: %{pid:{free: , state: (up or down)} }

  defstruct [
    conn: %{}
  ]

  def start_link() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid}
  end

  def init(args) do
    {:ok, %__MODULE__{conn: %{}}}
  end

  def handle_info(msg, state) do

  end

  def handle_call(request, from, state) do
    {:ok, pid} = Worker.start_link()
    # Choice logic
    # Check state, if connection exists and streams free then use it
    cancel_ref = :erlang.make_ref()
    GenServer.call(pid,  {request, cancel_ref})

  end


end
