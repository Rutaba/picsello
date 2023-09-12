defmodule PicselloWeb.BookingProposalLive.IdleComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{PaymentSchedules, BookingProposal}
  import PicselloWeb.LiveModal, only: [footer: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog">
      <div class="mb-4 md:mb-8">
        <.maybe_show_photographer_logo? organization={@organization} />
      </div>

      <h1 class="mb-4 text-3xl font-light">Your session isn’t fully booked</h1>
      <p>You need to complete all steps including finalizing payment.</p>

      <.footer>
        <button class="btn-primary" phx-click="modal" phx-value-action="close" type="button">
          Finish booking
        </button>
        <button class="btn-secondary" phx-click="modal" phx-value-action="close" type="button">
          Close
        </button>
      </.footer>
    </div>
    """
  end

  def open_modal_from_proposal(socket, proposal, read_only \\ true) do
    %{
      job:
        %{
          package: %{organization: organization}
        } = job
    } = BookingProposal.preloads(proposal)

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || PaymentSchedules.all_paid?(job),
      organization: organization
    })
  end
end
