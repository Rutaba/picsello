defmodule PicselloWeb.BookingProposalLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view_client
  alias Picsello.{Repo, BookingProposal, Job}

  @max_age 60 * 60 * 24 * 7

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket
    |> assign(:current_user, nil)
    |> assign_proposal(token)
    |> ok()
  end

  defp assign_proposal(socket, token) do
    case Phoenix.Token.verify(PicselloWeb.Endpoint, "PROPOSAL_ID", token, max_age: @max_age) do
      {:ok, proposal_id} ->
        proposal =
          Repo.get!(BookingProposal, proposal_id)
          |> Repo.preload(job: [package: :organization])

        %{job: %{package: %{organization: organization} = package} = job} = proposal

        socket
        |> assign(proposal: proposal, job: job, package: package, organization: organization)

      {:error, _} ->
        socket
        |> assign(proposal: nil)
        |> put_flash(:error, "This proposal is not available anymore")
    end
  end
end
