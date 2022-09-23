defmodule PicselloWeb.BookingProposalLive.ScheduleComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.PaymentSchedules

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def handle_event("pay_invoice", %{}, %{assigns: %{job: job}} = socket) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket) |> noreply()
    else
      stripe_checkout(socket) |> noreply()
    end
  end

  defp make_status(schedule) do
    cond do
      not is_nil(schedule.paid_at) ->
        "Paid #{schedule.paid_at |> format_date_via_type()}"

      DateTime.compare(schedule.due_at, DateTime.utc_now()) == :lt ->
        "Overdue #{schedule.due_at |> format_date_via_type()}"

      DateTime.compare(schedule.due_at, DateTime.utc_now()) == :gt ->
        "Upcoming #{schedule.due_at |> format_date_via_type()}"
    end
  end

  defp status_class(status_string) do
    status = String.split(status_string, " ") |> Enum.at(0)

    case status do
      "Paid" ->
        "text-green-finances-300"

      "Overdue" ->
        "text-red-sales-300"

      "Upcoming" ->
        "text-black"
    end
  end

  defp button_text_for_status(schedules) do
    overdue_schedules =
      Enum.filter(schedules, fn schedule ->
        is_nil(schedule.paid_at) and DateTime.compare(schedule.due_at, Timex.now()) == :lt
      end)

    if overdue_schedules != [] do
      _schedule = hd(overdue_schedules)
      "Pay overdue invoice"
    else
      "Pay upcoming invoice"
    end
  end
end
