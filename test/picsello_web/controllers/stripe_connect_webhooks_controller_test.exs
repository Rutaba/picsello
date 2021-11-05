defmodule PicselloWeb.StripeConnectWebhooksControllerTest do
  use PicselloWeb.ConnCase, async: true
  alias Picsello.{Repo, BookingProposal}

  def stub_event(%{proposal_id: proposal_id, paying_for: paying_for}) do
    Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
      {:ok,
       %{
         type: "checkout.session.completed",
         data: %{
           object: %{
             client_reference_id: "proposal_#{proposal_id}",
             metadata: %{"paying_for" => paying_for}
           }
         }
       }}
    end)
  end

  setup do
    user = insert(:user)
    proposal = insert(:proposal, job: promote_to_job(insert(:lead, user: user)))

    [proposal: proposal, user: user]
  end

  def make_request(conn) do
    conn
    |> put_req_header("stripe-signature", "love, stripe")
    |> post(Routes.stripe_connect_webhooks_path(conn, :webhooks), %{})
  end

  describe "deposit webhook" do
    setup %{proposal: proposal} do
      stub_event(%{proposal_id: proposal.id, paying_for: "deposit"})

      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

      :ok
    end

    test "emails photographer", %{conn: conn, user: %{email: user_email}} do
      make_request(conn)

      assert_receive {:delivered_email, %{to: [nil: ^user_email]}}
    end

    test "marks booking proposal as paid", %{conn: conn, proposal: %{id: proposal_id}} do
      make_request(conn)

      %{deposit_paid_at: time} = Repo.get(BookingProposal, proposal_id)

      refute is_nil(time)
    end
  end

  describe "remainder webhook" do
    test "marks booking proposal as paid", %{conn: conn, proposal: proposal} do
      proposal |> BookingProposal.deposit_paid_changeset() |> Repo.update!()

      stub_event(%{proposal_id: proposal.id, paying_for: "remainder"})

      make_request(conn)

      %{remainder_paid_at: time} = Repo.get(BookingProposal, proposal.id)

      refute is_nil(time)
    end
  end
end
