defmodule Picsello.WHCC.WebhookKeeper do
  @moduledoc """
  Ensures webhook is registered when URL provided

  If no url defined  it stays in :sleep
  Otherwise it lives in :started -> :in_progress -> :ok/:error lifecycle
  :ok/:error states set timer to go throu registration in :in_progress state

  """
  use GenServer

  import PicselloWeb.LiveHelpers, only: [noreply: 1]
  require Logger

  @resubscribe_timeout :timer.hours(6)
  @retry_timeout :timer.minutes(1)

  @whcc_config Application.compile_env(:picsello, :whcc)

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    enabled =
      @whcc_config
      |> Keyword.get(:webhook_url)
      |> then(&(&1 != ""))

    if enabled do
      timer = Process.send_after(self(), :register, @retry_timeout)
      {:ok, {:started, DateTime.utc_now(), timer}}
    else
      {:ok, {:sleep, DateTime.utc_now(), nil}}
    end
  end

  @doc "Returns {last_responce, date_time, timer}"
  def state() do
    GenServer.call(__MODULE__, :state)
  end

  def finish_verification(hash) do
    GenServer.cast(__MODULE__, {:finish, hash})
  end

  @impl true
  def handle_call(:state, _, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:finish, _}, {:sleep, _, _} = state), do: state |> noreply()

  def handle_cast({:finish, hash}, {_, _, timer}) do
    %{"isVerified" => true} = Picsello.WHCC.webhook_verify(hash)
    Process.cancel_timer(timer)
    Logger.info("[whcc] Webhook registered successfully")

    {:ok, DateTime.utc_now(), Process.send_after(self(), :register, @resubscribe_timeout)}
    |> noreply()
  end

  @impl true
  def handle_info(:register, _) do
    case register() do
      :ok ->
        {:in_progress, DateTime.utc_now(),
         Process.send_after(self(), :register, @resubscribe_timeout)}

      e ->
        {e, DateTime.utc_now(), Process.send_after(self(), :register, @retry_timeout)}
    end
    |> noreply()
  end

  defp register() do
    Picsello.WHCC.webhook_register(@whcc_config |> Keyword.get(:webhook_url))
  end
end
