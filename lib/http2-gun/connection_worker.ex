defmodule HTTP2Gun.ConnectionWorker do
  use GenServer

  alias HTTP2Gun.ConnectionWorker, as: Worker
  alias HTTP2Gun.Request
  alias HTTP2Gun.Response
  alias HTTP2Gun.Error
  require Logger

  defstruct [
    :host,
    :port,
    :opts,
    :gun_pid,
    :gun_ref,
    :pool_conn_pid,
    streams: %{},
    cancels: %{}
  ]

  def start_link(state) do
    {:ok, pid} = GenServer.start_link(HTTP2Gun.ConnectionWorker, state)
    Logger.info("start connection worker #{Kernel.inspect(pid)}")
    {:ok, pid}
  end

  def init(state) do
    {:ok, pid} = :gun.open(String.to_charlist(state.host), state.port,
                           %{retry: 0, retry_timeout: 0})
    {:ok, %Worker{gun_pid: pid, host: state.host,
                  port: state.port, opts: state.opts, pool_conn_pid: state.pool_conn_pid}}
  end

  def handle_info({:gun_up, conn_pid, protocol}, state) do
    Logger.info(":gun_up #{Kernel.inspect(conn_pid)}")
    {:noreply, state}
  end

  def handle_info({:gun_data, conn_pid, stream_ref, is_fin, data}, state) do
    Logger.info(":gun_data #{Kernel.inspect(conn_pid)}")
    state_new = case state.streams |> Map.get(stream_ref)do
      nil ->
        {:noreply, state}
      {from, response, cancel_ref, timer_ref, pid_src} ->
        response = %Response{response | body: data}
          case is_fin do
            :nofin -> continue(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref, pid_src,
                        state)
            :fin -> reply(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref, pid_src,
                        state)
          end
    end

    {:noreply, state_new}
  end

  def handle_info({:gun_response, conn_pid, stream_ref, is_fin, status, headers}, state) do
    Logger.info(":gun_response #{Kernel.inspect(conn_pid)}")
    state_new = case state.streams |> Map.get(stream_ref) do
      nil ->
        {:noreply, state}
      {from, response, cancel_ref, timer_ref, pid_src} ->
        response = %Response{response | headers: headers,
                          status_code: status}
        case is_fin do
            :nofin -> continue(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref, pid_src,
                        state)
            :fin -> reply(stream_ref, is_fin,
                        from, response,
                        cancel_ref, timer_ref, pid_src,
                        state)
        end
    end

    {:noreply, state_new}
  end

  def handle_info({:timeout, from, cancel_ref},
                  %Worker{gun_pid: gun_pid, streams: streams, cancels: cancels}=state) do
    Logger.info(":timeout #{Kernel.inspect(from)}")
    case cancels |> Map.get(cancel_ref) do
      nil ->
        Enum.each(Map.values(streams), fn {_from, _response, _cancel_ref, _timer_ref, pid_src} -> GenServer.reply(pid_src, %Error{reason: "Timeout stream",
                                                                                                                                  source: __MODULE__}) end)
        {:noreply, state}
      stream_ref ->
        Enum.each(Map.values(streams), fn {_from, _response, _cancel_ref, _timer_ref, pid_src} -> GenServer.reply(pid_src,  %Error{reason: "Timeout stream",
                                                                                                                                   source: __MODULE__}) end)
        :ok = :gun.close(gun_pid)
        {:noreply, clean_refs(state, stream_ref, cancel_ref)}
    end
  end

  def handle_info({:gun_error, conn_pid, streamRef, reason}, %Worker{streams: streams, gun_pid: gun_pid}=state) do
    Logger.info(":gun_error #{Kernel.inspect(conn_pid)}")
    Enum.each(Map.values(streams), fn {_from, _response, _cancel_ref, _timer_ref, pid_src} -> GenServer.reply(pid_src, %Error{reason: "GUN ERROR",
                                                                                                                              source: __MODULE__}) end)
    {:noreply, state}
  end

  def handle_info({:gun_error, conn_pid, reason}, %Worker{streams: streams, gun_pid: gun_pid}=state) do
    Logger.info(":gun_error #{Kernel.inspect(conn_pid)}")
    Enum.each(Map.values(streams), fn {_from, _response, _cancel_ref, _timer_ref, pid_src} -> GenServer.reply(pid_src, %Error{reason: "GUN ERROR",
                                                                                                                              source: __MODULE__}) end)
    {:noreply, state}
  end

  def handle_info({:gun_down, gun_pid, _protocol, reason, _killed_streams, unprocessed_streams},
  %Worker{streams: streams, gun_pid: gun_pid}=state) do
    Logger.info(":gun_down #{Kernel.inspect(gun_pid)}")
    Enum.each(Map.values(streams), fn {_from, _response, _cancel_ref, _timer_ref, pid_src} -> GenServer.reply(pid_src, %Error{reason: "GUN DOWN",
                                                                                                                              source: __MODULE__}) end)
    {:noreply, state}
  end

  def handle_cast({%Request{method: method, path: path, body: body, headers: headers}, pid_src},
                    %Worker{streams: streams, cancels: cancels, pool_conn_pid: from_pid}=state) do
    timeout = Application.get_env(:http2_gun, :time_for_timeout)
    Logger.info("connection worker request from #{Kernel.inspect(pid_src)}")
    cancel_ref = :erlang.make_ref()
    timer_ref = Process.send_after(self(), {:timeout, pid_src, cancel_ref}, timeout)
    stream_ref = :gun.request(state.gun_pid, String.to_charlist(method),
                              String.to_charlist(path), headers, String.to_charlist(body))
    {:noreply, %{state |
      streams: (
        streams |> Map.put(stream_ref, {from_pid, %Response{},
                                        cancel_ref, timer_ref, pid_src})
        ),
      cancels: (
        cancels |> Map.put(cancel_ref, stream_ref)
        )
      }
    }
  end

  def reply(stream_ref, _is_fin, from, response, cancel_ref, timer_ref, pid_src,
              %Worker{streams: _streams, cancels: _cancels}=state) do
    Process.cancel_timer(timer_ref)
    GenServer.cast(from, {response, pid_src})
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

  def continue(stream_ref, _is_fin, from, response, cancel_ref, timer_ref, pid_src,
                %Worker{streams: streams}=state) do
    %{state |
      streams: (
        streams |> Map.put(stream_ref, {from, response,
                                        cancel_ref, timer_ref, pid_src})
      )
    }
  end
end
