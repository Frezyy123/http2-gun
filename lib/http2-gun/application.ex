defmodule HTTP2Gun.Application do
  use Application
  use DynamicSupervisor

  @spec start(any(), any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
      children = [
        %{
          id: GenServerProcess,
          start: {HTTP2Gun.ConnectionWorker, :start_link, []}
        }
      ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end


end
