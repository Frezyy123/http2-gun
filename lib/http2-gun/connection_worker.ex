defmodule HTTP2Gun.ConnectionWorker do
  use GenServer
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request

  defmodule Response do
    defstruct [
      :request_url,
      :status_code,
      :headers,
      :body
    ]
  end

  defstruct [
    :host,
    :port,
    :opts,
    :gun_pid,
    :gun_ref,
    :m_mod,
    :m_state,
    streams: %{},
    cancels: %{}
  ]

  defmodule Error do
    defexception reason: nil
    def message(%__MODULE__{reason: reason}), do: inspect(reason)
  end

  def start_link() do

    {:ok, pid} = GenServer.start_link(HTTP2Gun.ConnectionWorker, [])

    {:ok, pid}
  end

  def init(args) do

    {:ok, %Worker{host: "localhost", port: 443, opts: [], m_mod: nil}}
  end

  def handle_info({:gun_response, gun_pid, stream_ref, is_fin, status, headers},
                    %Worker{gun_pid: gun_pid, streams: streams} = worker) do
    case streams |> Map.get(stream_ref) do
      nil ->
        {:noreply, worker}
      {from, %Response{} = response, cancel_ref} ->
        response = %Response{response |
          status_code: status,
          headers: headers,
          body: ""
        }
        stream_result = streams |> Map.put(stream_ref, {from, response, cancel_ref})
        {:noreply, %{worker |streams: (stream_result)}}
    end

  end


  def handle_call({%Request{method: method, path: path, headers: headers, body: body}, cancel_ref}, from, state) do
      state |> IO.inspect

      # {:ok, gun_pid} = :gun.open("localhost", 443)

      # stream_ref = :gun.request(gun_pid, method, path, headers, body, %{})


      # streams_result = streams |> Map.put(stream_ref, {from, %Response{}, cancel_ref})
      # cancels_result = cancels |> Map.put(cancel_ref, stream_ref)

      # {:noreply, %{worker | streams: streams_result, cancels: cancels_result}}
  end


end
