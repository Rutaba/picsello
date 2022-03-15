defmodule PicselloWeb.StripeConnectWebhooksControllerTest do
  use PicselloWeb.ConnCase, async: true
  alias Picsello.{Repo, PaymentSchedule}

  def stub_event(%{proposal_id: proposal_id, paying_for: paying_for}) do
    Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
      {:ok,
       %{
         type: "checkout.session.completed",
         data: %{
           object: %Stripe.Session{
             client_reference_id: "proposal_#{proposal_id}",
             metadata: %{"paying_for" => paying_for}
           }
         }
       }}
    end)
  end

  setup do
    user = insert(:user)

    job = insert(:lead, user: user) |> promote_to_job() |> Repo.preload(:payment_schedules)
    proposal = insert(:proposal, job: job)
    [deposit_payment, remainder_payment] = job.payment_schedules |> Enum.sort_by(& &1.due_at)

    Repo.update_all(PaymentSchedule, set: [paid_at: nil])

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    [
      proposal: proposal,
      job: job,
      user: user,
      deposit_payment: deposit_payment,
      remainder_payment: remainder_payment
    ]
  end

  def make_request(conn) do
    conn
    |> put_req_header("stripe-signature", "love, stripe")
    |> post(Routes.stripe_connect_webhooks_path(conn, :webhooks), %{})
  end

  describe "deposit webhook" do
    setup %{proposal: proposal, deposit_payment: deposit_payment} do
      stub_event(%{proposal_id: proposal.id, paying_for: deposit_payment.id})

      :ok
    end

    test "emails photographer", %{conn: conn, user: %{email: user_email}} do
      make_request(conn)

      assert_receive {:delivered_email, %{to: [nil: ^user_email]}}
    end

    test "marks payment schedule as paid", %{conn: conn, deposit_payment: deposit_payment} do
      make_request(conn)

      %{paid_at: time} = deposit_payment |> Repo.reload!()

      refute is_nil(time)
    end
  end

  describe "remainder webhook" do
    test "marks booking proposal as paid", %{
      conn: conn,
      proposal: proposal,
      deposit_payment: deposit_payment,
      remainder_payment: remainder_payment
    } do
      deposit_payment |> PaymentSchedule.paid_changeset() |> Repo.update!()

      stub_event(%{proposal_id: proposal.id, paying_for: remainder_payment.id})

      make_request(conn)

      %{paid_at: time} = remainder_payment |> Repo.reload!()

      refute is_nil(time)
    end
  end
end
