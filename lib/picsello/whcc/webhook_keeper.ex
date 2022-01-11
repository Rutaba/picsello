defmodule Picsello.WHCC.WebhookKeeper do
  @moduledoc """
  Ensures webhook is registered when URL provided
  """
  use GenServer

  import PicselloWeb.LiveHelpers, only: [noreply: 1]

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
      Process.send_after(self(), :register, @retry_timeout)
    end

    {:ok, {:sleep, DateTime.utc_now(), nil}}
  end

  @doc "Returns {last_responce, date_time, timer}"
  def state() do
    GenServer.call(__MODULE__, :state)
  end

  @impl true
  def handle_call(:state, _, state), do: {:reply, state, state}

  @impl true
  def handle_info(:register, _) do
    case register() do
      :ok ->
        {:ok, DateTime.utc_now(), Process.send_after(self(), :register, @resubscribe_timeout)}

      e ->
        {e, DateTime.utc_now(), Process.send_after(self(), :register, @retry_timeout)}
    end
    |> noreply()
  end

  defp register() do
    Picsello.WHCC.webhook_register(@whcc_config |> Keyword.get(:webhook_url))
  end
end
