defmodule Picsello.Workers.SendPaymentScheduleReminder do
  @moduledoc false
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  @impl Oban.Worker
  def perform(_) do
    if balance_due_emails_enabled?() do
      Picsello.PaymentSchedules.deliver_reminders(PicselloWeb.Helpers)
    end

    :ok
  end

  defp balance_due_emails_enabled?,
    do: Enum.member?(Application.get_env(:picsello, :feature_flags, []), :balance_due_emails)
end
