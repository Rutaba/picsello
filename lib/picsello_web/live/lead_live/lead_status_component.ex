defmodule PicselloWeb.LeadLive.LeadStatusComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Repo, BookingProposal}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign_status(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="flex mt-2">
      <div class="w-1/2 p-2 mr-2 font-bold border rounded-lg text-blue-primary border-blue-primary"><%= @next_status %></div>
      <div class="flex w-1/2 ml-2 overflow-hidden font-bold text-gray-400 border border-gray-300 rounded-lg">
        <div class="flex flex-col items-center justify-center px-2 mr-2 text-xs font-semibold bg-gray-200">
          <div class="uppercase"><%= @month %></div>
          <div><%= @day %></div>
        </div>
        <div class="flex items-center"><%= @current_status %></div>
      </div>
    </div>
    """
  end

  defp assign_status(socket, %{proposal: proposal}) do
    proposal = proposal |> Repo.preload(:answer)
    status = BookingProposal.status(proposal)

    {current_status, next_status, date} = current_statuses(status, proposal)
    month = Calendar.strftime(date, "%b")
    day = Calendar.strftime(date, "%d")

    socket
    |> assign(current_status: current_status, next_status: next_status, month: month, day: day)
  end

  defp current_statuses(:sent, proposal),
    do: {"Proposal sent", "Awaiting acceptance", proposal.inserted_at}

  defp current_statuses(:accepted, proposal),
    do: {"Proposal accepted", "Awaiting contract", proposal.accepted_at}

  defp current_statuses(:signed, %{questionnaire_id: nil} = proposal),
    do: {"Proposal signed", "Pending payment", proposal.signed_at}

  defp current_statuses(:signed, proposal),
    do: {"Proposal signed", "Awaiting questionnaire", proposal.signed_at}

  defp current_statuses(:answered, proposal),
    do: {"Questionnaire answered", "Pending payment", proposal.answer.inserted_at}

  defp current_statuses(:deposit_paid, proposal),
    do: {"Payment paid", "Job created", proposal.deposit_paid_at}
end
