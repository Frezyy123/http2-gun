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

  def start_link(state) do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.ConnectionWorker, state, name: __MODULE__)
    {:ok, pid}
  end

  def init(state) do
    {:ok, pid} = :gun.open(String.to_charlist(state.host), state.port)

    {:ok, %Worker{gun_pid: pid, host: state.host, port: state.port, opts: state.opts}}
  end

  def handle_info({:gun_up, conn_pid, protocol}, state) do
    {:gun_up, conn_pid, protocol} |> IO.inspect
    {:noreply, state}
  end

  def handle_info({:gun_data, conn_pid, stream_ref, is_fin, data}, state) do
    {:gun_data, conn_pid} |> IO.inspect
    {from, response, cancel_ref} = Map.get(state.streams, stream_ref)
    IO.puts("-------> Gun DATA")
    response = %Response{response |
      body: data
      } #|> IO.inspect
    state_new = reply(stream_ref, is_fin, from, response, cancel_ref, state)
    {:noreply, state_new}
  end

  def handle_info({:gun_response, conn_pid, stream_ref, is_fin, status, headers}, state) do
    {:gun_response, conn_pid, stream_ref} |> IO.inspect
    {from, response, cancel_ref} = Map.get(state.streams, stream_ref)
    IO.puts("-------> Gun RESPONSE")
    response = %Response{response |
      headers: headers,
      status_code: status
      } #|> IO.inspect
    state_new = continue(stream_ref, is_fin, from, response, cancel_ref, state)
    {:noreply, state_new}
  end

  # def handle_info(msg, state) do
  #   msg |> IO.inspect
  #   {:noreply, state}
  # end

  def handle_call({%Request{method: method, path: path, headers: headers, body: body}, cancel_ref}, from,
                    %Worker{streams: streams, cancels: cancels}=state) do
    IO.puts("-------> Connection worker REQUEST")
    # state |> IO.inspect
    # {:ok, gun_pid} = :gun.open("localhost", 443)
    stream_ref = :gun.request(state.gun_pid, String.to_charlist(method), String.to_charlist(path), [])
    # stream_ref = :gun.get(state.gun_pid, path) |> IO.inspect
    # :gun.await(state.gun_pid, stream_ref) |> IO.inspect
    # streams_result = streams |> Map.put(stream_ref, {from, %Response{}, cancel_ref})
    # cancels_result = cancels |> Map.put(cancel_ref, stream_ref)
    # GenServer.reply(from, "Response") |> IO.inspect

    {:noreply, %{state |
      streams: (
        streams |> Map.put(stream_ref, {from, %Response{}, cancel_ref})
        ),
      cancels: (
        cancels |> Map.put(cancel_ref, stream_ref)
        )
      }
    }
  end

  defp reply(stream_ref, is_fin, from, response, cancel_ref,
              %Worker{streams: streams, cancels: cancels}=state) do
    if is_fin == :fin do
      :ok = GenServer.reply(from, {:ok, response})
      %{state |
        streams: (
          streams |> Map.delete(stream_ref)
        ),
        cancels: (
          cancels |> Map.delete(cancel_ref)
        )
      }
    end
  end

  defp continue(stream_ref, is_fin, from, response, cancel_ref,
                %Worker{streams: streams}=state) do
    %{state |
      streams: (
        streams |> Map.put(stream_ref, {from, response, cancel_ref})
      )
    }
  end
end
