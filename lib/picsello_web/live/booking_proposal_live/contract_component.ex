defmodule PicselloWeb.BookingProposalLive.ContractComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, BookingProposal, Contracts}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [banner: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"booking_proposal" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"booking_proposal" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, proposal} ->
        send(self(), {:update, %{proposal: proposal}})

        socket
        |> close_modal()
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Failed to sign contract. Please try again.")
        |> noreply()
    end
  end

  defp build_changeset(%{assigns: %{proposal: proposal}}, params) do
    proposal
    |> BookingProposal.sign_changeset(params)
  end

  defp assign_changeset(socket, action \\ nil, params \\ %{}) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end

  def open_modal_from_proposal(socket, proposal, read_only \\ true) do
    %{
      job:
        %{
          package: %{organization: %{user: photographer} = organization} = package,
          client: client,
          contract: contract
        } = job
    } = proposal |> Repo.preload(job: [:client, :contract, package: [organization: :user]])

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || proposal.signed_at != nil,
      client: client,
      job: job,
      contract_content:
        Contracts.contract_content(
          contract,
          job,
          PicselloWeb.Helpers
        ),
      proposal: proposal,
      package: package,
      photographer: photographer,
      organization: organization
    })
  end
end
