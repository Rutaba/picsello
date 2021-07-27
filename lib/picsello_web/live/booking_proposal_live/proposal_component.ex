defmodule PicselloWeb.BookingProposalLive.ProposalComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, Job, BookingProposal}

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
end
