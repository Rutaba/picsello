defmodule Picsello.ProposalReminderScheduler do
  @moduledoc false
  use GenServer
  alias Picsello.ProposalReminder

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    ProposalReminder.deliver_all()

    schedule_work()

    {:noreply, state}
  end

  defp schedule_work do
    Process.send_after(self(), :work, :timer.minutes(10))
  end
end
