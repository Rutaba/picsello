defmodule PicselloWeb.StripeConnectWebhooksController do
  use PicselloWeb, :controller
  alias Picsello.Repo
  alias Picsello.BookingProposal

  def webhooks(%Plug.Conn{assigns: %{stripe_event: stripe_event}} = conn, _params) do
    case handle_webhook(stripe_event, conn) do
      {:ok, _} -> handle_success(conn)
      {:error, error} -> handle_error(conn, error)
    end
  end

  defp handle_success(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  defp handle_error(conn, error) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(422, error)
  end

  def handle_webhook(
        %{type: "checkout.session.completed", data: %{object: session}},
        conn
      ) do
    "proposal_" <> proposal_id = session.client_reference_id
    proposal = Repo.get!(BookingProposal, proposal_id)

    %{metadata: %{"paying_for" => paying_for}} = session

    case paying_for do
      "deposit" ->
        proposal |> BookingProposal.deposit_paid_changeset() |> Repo.update!()
        url = Routes.job_url(conn, :jobs)
        Picsello.Notifiers.UserNotifier.deliver_lead_converted_to_job(proposal, url)
        {:ok, true}

      "remainder" ->
        proposal
        |> BookingProposal.remainder_paid_changeset()
        |> Repo.update!()

        {:ok, true}

      error ->
        {:error, error}
    end
  end

  def handle_webhook(_stripe_event, _conn), do: {:ok, "success"}
end
