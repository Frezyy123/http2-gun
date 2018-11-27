defmodule HTTP2Gun.ConnectionWorker do
  use GenServer
  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  alias HTTP2Gun.Response

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

  def start_link(state, _name) do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.ConnectionWorker, state)
    {:ok, pid}
  end

  def init(state) do
    {:ok, pid} = :gun.open(String.to_charlist(state.host), state.port,
                           %{retry: 0, retry_timeout: 0})
    {:ok, %Worker{gun_pid: pid, host: state.host,
                  port: state.port, opts: state.opts}}
  end

  def handle_info({:gun_up, conn_pid, protocol}, state) do
    IO.puts("-------> Gun UP")
    {:noreply, state}
  end

  def handle_info({:gun_data, conn_pid, stream_ref, is_fin, data}, state) do
    IO.puts("-------> Gun DATA")
    case state.streams |> Map.get(stream_ref) do
      nil ->
        {:noreply, state}
      {from, response, cancel_ref, timer_ref} ->
        response = %Response{response | body: data}
        state_new =
          case is_fin do
            :nofin -> continue(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref,
                        state)
            :fin -> reply(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref,
                        state)
          end
        {:noreply, state_new}
    end
  end

  def handle_info({:gun_response, conn_pid, stream_ref, is_fin, status, headers}, state) do
    IO.puts("-------> Gun RESPONSE")
    {from, response, cancel_ref, timer_ref} = Map.get(state.streams, stream_ref)
    state_new = case state.streams |> Map.get(stream_ref) do
      nil ->
        {:noreply, state}
      {from, response, cancel_ref, timer_ref} ->
            response = %Response{response | headers: headers,
                         status_code: status}
        case is_fin do
            :nofin -> continue(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref,
                        state)
            :fin -> reply(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref,
                        state)
        end
    end
    {:noreply, state_new}
  end

  def handle_info({:timeout, from, cancel_ref},
                  %Worker{gun_pid: gun_pid, cancels: cancels}=state) do
    IO.puts("-------> TIMEOUT")
    case cancels |> Map.get(cancel_ref) do
      nil ->
        GenServer.reply(from, :timeout)
        {:noreply, state}
      stream_ref ->
        GenServer.reply(from, :timeout)
        :ok = :gun.close(gun_pid)
        {:noreply, clean_refs(state, stream_ref, cancel_ref)}
    end
  end

  def handle_info({:gun_error, _, _, _}, state) do
    IO.puts("-------> Gun ERROR")
    {:noreply, state}
  end

  # def handle_info(msg, state) do
  #   msg |> IO.inspect
  #   {:noreply, state}
  # end

  def handle_call(%Request{method: method, path: path}, from,
                    %Worker{streams: streams, cancels: cancels}=state) do
    IO.puts("---------> Connection worker REQUEST")
    cancel_ref = :erlang.make_ref()
    timer_ref = Process.send_after(self(), {:timeout, from, cancel_ref}, 2000)
    stream_ref = :gun.request(state.gun_pid, String.to_charlist(method),
                              String.to_charlist(path), [])
    {:noreply, %{state |
      streams: (
        streams |> Map.put(stream_ref, {from, %Response{},
                                        cancel_ref, timer_ref})
        ),
      cancels: (
        cancels |> Map.put(cancel_ref, stream_ref)
        )
      }
    }
  end

  defp reply(stream_ref, _is_fin, from, response, cancel_ref, timer_ref,
              %Worker{streams: _streams, cancels: _cancels}=state) do
    Process.cancel_timer(timer_ref)
    :ok = GenServer.reply(from, {:ok, response})
    clean_refs(state, stream_ref, cancel_ref)
  end

  defp clean_refs(%Worker{streams: streams, cancels: cancels} = state, stream_ref, cancel_ref) do
    %{state |
        streams: (
          streams |> Map.delete(stream_ref)
        ),
        cancels: (
          cancels |> Map.delete(cancel_ref)
        )
      }
  end

  defp continue(stream_ref, _is_fin, from, response, cancel_ref, timer_ref,
                %Worker{streams: streams}=state) do
    %{state |
      streams: (
        streams |> Map.put(stream_ref, {from, response,
                                        cancel_ref, timer_ref})
      )
    }
  end
end
