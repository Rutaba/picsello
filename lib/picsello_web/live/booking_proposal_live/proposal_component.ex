defmodule PicselloWeb.BookingProposalLive.ProposalComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, BookingProposal, Package}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [banner: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def handle_event("accept-proposal", %{}, %{assigns: %{proposal: proposal}} = socket) do
    case proposal |> BookingProposal.accept_changeset() |> Repo.update() do
      {:ok, proposal} ->
        send(self(), {:update, %{proposal: proposal}})

        socket
        |> close_modal()
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to accept proposal. Please try again.")
        |> noreply()
    end
  end

  def open_modal_from_proposal(socket, proposal, read_only \\ true) do
    %{
      job:
        %{
          client: client,
          shoots: shoots,
          package: %{organization: %{user: photographer} = organization} = package
        } = job
    } =
      proposal
      |> Repo.preload(job: [:client, :shoots, package: [organization: :user]])

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || proposal.accepted_at != nil,
      job: job,
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package
    })
  end
end
