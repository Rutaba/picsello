defmodule Picsello.PaymentSchedulesTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.{PaymentSchedules, Repo}

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    user = insert(:user, email: "photographer@example.com")

    lead =
      insert(:lead, type: "wedding", user: user, client: [email: "elizabeth-lead@example.com"])

    insert(:email_preset, job_type: lead.type, state: :payment_confirmation_client)

    proposal = insert(:proposal, job: lead)

    payment_schedule =
      insert(:payment_schedule,
        job: lead,
        price: ~M[5000]USD
      )

    [lead: lead, proposal: proposal, payment_schedule: payment_schedule]
  end

  describe "build_payment_schedules_for_lead/1" do
    test "when package total price is zero" do
      %{id: lead_id} =
        lead =
        insert(:lead,
          package: %{shoot_count: 1, base_price: 2000, base_multiplier: 0},
          shoots: [%{starts_at: ~U[2029-09-30 19:00:00Z]}]
        )

      price = Money.new(0)

      assert %{
               details: "100% discount",
               payments: [
                 %{
                   job_id: ^lead_id,
                   price: ^price,
                   due_at: deposit_due,
                   description: "100% discount"
                 }
               ]
             } = PaymentSchedules.build_payment_schedules_for_lead(lead)

      assert deposit_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
    end

    test "when type is headshot or mini" do
      for type <- ~w[headshot mini] do
        %{id: lead_id} =
          lead =
          insert(:lead,
            type: type,
            package: %{shoot_count: 2, base_price: 2000},
            shoots: [
              %{starts_at: ~U[2029-09-30 19:00:00Z]},
              %{starts_at: ~U[2039-09-30 19:00:00Z]}
            ]
          )

        price = Money.new(2000)

        assert %{
                 details: "100% retainer",
                 payments: [
                   %{
                     job_id: ^lead_id,
                     price: ^price,
                     due_at: deposit_due,
                     description: "100% retainer"
                   }
                 ]
               } = PaymentSchedules.build_payment_schedules_for_lead(lead)

        assert deposit_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
      end
    end

    test "when type is wedding and wedding date is > 6 months" do
      wedding_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 * 365)
      one_month_from_wedding = DateTime.add(wedding_date, 60 * 60 * 24 * 30 * -1)
      seven_months_from_wedding = DateTime.add(wedding_date, 60 * 60 * 24 * 30 * -7)

      %{id: lead_id} =
        lead =
        insert(:lead,
          type: "wedding",
          package: %{shoot_count: 2, base_price: 2000},
          shoots: [
            %{starts_at: DateTime.utc_now()},
            %{starts_at: wedding_date}
          ]
        )

      price1 = Money.new(700)
      price2 = Money.new(700)
      price3 = Money.new(600)

      assert %{
               details:
                 "35% retainer, 35% six months to the wedding, 30% one month before the wedding",
               payments: [
                 %{
                   job_id: ^lead_id,
                   price: ^price1,
                   due_at: deposit1_due,
                   description: "35% retainer"
                 },
                 %{
                   job_id: ^lead_id,
                   price: ^price2,
                   due_at: deposit2_due,
                   description: "35% second payment"
                 },
                 %{
                   job_id: ^lead_id,
                   price: ^price3,
                   due_at: deposit3_due,
                   description: "30% remainder"
                 }
               ]
             } = PaymentSchedules.build_payment_schedules_for_lead(lead)

      assert deposit1_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
      assert deposit2_due |> DateTime.to_date() == seven_months_from_wedding |> DateTime.to_date()
      assert deposit3_due |> DateTime.to_date() == one_month_from_wedding |> DateTime.to_date()
    end

    test "when type is wedding and wedding date is < 6 months" do
      wedding_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 * 150)
      one_month_from_wedding = DateTime.add(wedding_date, 60 * 60 * 24 * 30 * -1)

      %{id: lead_id} =
        lead =
        insert(:lead,
          type: "wedding",
          package: %{shoot_count: 2, base_price: 2000},
          shoots: [
            %{starts_at: DateTime.utc_now()},
            %{starts_at: wedding_date}
          ]
        )

      price1 = Money.new(1400)
      price2 = Money.new(600)

      assert %{
               details: "70% retainer and 30% one month before shoot",
               payments: [
                 %{
                   job_id: ^lead_id,
                   price: ^price1,
                   due_at: deposit1_due,
                   description: "70% retainer"
                 },
                 %{
                   job_id: ^lead_id,
                   price: ^price2,
                   due_at: deposit2_due,
                   description: "30% remainder"
                 }
               ]
             } = PaymentSchedules.build_payment_schedules_for_lead(lead)

      assert deposit1_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
      assert deposit2_due |> DateTime.to_date() == one_month_from_wedding |> DateTime.to_date()
    end

    test "when it's not wedding, headshot or mini returns list with deposit and remainder attributes" do
      for type <- ~w[family newborn maternity event portrait other boudoir] do
        %{id: lead_id} =
          lead =
          insert(:lead,
            type: type,
            package: %{shoot_count: 2, base_price: 2000},
            shoots: [
              %{starts_at: ~U[2029-09-30 19:00:00Z]},
              %{starts_at: ~U[2039-09-30 19:00:00Z]}
            ]
          )

        price = Money.new(1000)

        assert %{
                 details: "50% retainer and 50% on day of shoot",
                 payments: [
                   %{
                     job_id: ^lead_id,
                     price: ^price,
                     due_at: deposit_due,
                     description: "50% retainer"
                   },
                   %{
                     job_id: ^lead_id,
                     price: ^price,
                     due_at: ~U[2029-09-29 19:00:00Z],
                     description: "50% remainder"
                   }
                 ]
               } = PaymentSchedules.build_payment_schedules_for_lead(lead)

        assert deposit_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
      end
    end
  end

  describe "deliver_reminders/0" do
    test "only sends reminders to payments with recent due date" do
      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

      lead1 = insert(:lead, type: "wedding", client: [email: "elizabeth-lead@example.com"])

      job1 =
        insert(:lead, type: "wedding", client: [email: "elizabeth1@example.com"])
        |> promote_to_job()

      job2 =
        insert(:lead, type: "wedding", client: [email: "elizabeth2@example.com"])
        |> promote_to_job()

      job3 =
        insert(:lead, type: "wedding", client: [email: "elizabeth2@example.com"])
        |> promote_to_job()

      completed_job =
        insert(:lead,
          type: "wedding",
          client: [email: "elizabeth+completed@example.com"],
          completed_at: DateTime.utc_now()
        )
        |> promote_to_job()

      insert(:email_preset,
        state: :balance_due,
        job_type: "wedding",
        body_template: "<p>{{invoice_amount}}</p>"
      )

      payment_lead =
        insert(:payment_schedule,
          job: lead1,
          price: ~M[5000]USD,
          due_at: DateTime.utc_now() |> DateTime.add(2 * :timer.hours(24), :millisecond)
        )

      payment1 =
        insert(:payment_schedule,
          job: job1,
          price: ~M[5000]USD,
          due_at: DateTime.utc_now() |> DateTime.add(2 * :timer.hours(24), :millisecond)
        )

      payment2 =
        insert(:payment_schedule,
          job: job2,
          price: ~M[5000]USD,
          due_at: DateTime.utc_now() |> DateTime.add(4 * :timer.hours(24), :millisecond)
        )

      _payment_from_completed_job =
        insert(:payment_schedule,
          job: completed_job,
          price: ~M[5000]USD,
          due_at: DateTime.utc_now() |> DateTime.add(2 * :timer.hours(24), :millisecond)
        )

      already_reminded_at = DateTime.utc_now() |> DateTime.add(-100)

      payment3 =
        insert(:payment_schedule,
          job: job3,
          price: ~M[5000]USD,
          due_at: DateTime.utc_now() |> DateTime.add(2 * :timer.hours(24), :millisecond),
          reminded_at: already_reminded_at
        )

      PaymentSchedules.deliver_reminders(PicselloWeb.Helpers)

      refute payment1 |> Repo.reload!() |> Map.get(:reminded_at) |> is_nil()
      assert payment2 |> Repo.reload!() |> Map.get(:reminded_at) |> is_nil()
      assert payment_lead |> Repo.reload!() |> Map.get(:reminded_at) |> is_nil()

      assert payment3 |> Repo.reload!() |> Map.get(:reminded_at) ==
               already_reminded_at |> DateTime.truncate(:second)

      assert_receive {:delivered_email, %{to: [nil: "elizabeth1@example.com"]}}
      job_id = job1.id
      assert [%{job_id: ^job_id, body_text: "$50.00"}] = Repo.all(Picsello.ClientMessage)
    end
  end

  describe "handle_payment/2" do
    test "updates paid_at and sends email to photographer and client", %{
      proposal: proposal,
      payment_schedule: payment_schedule
    } do
      result =
        PaymentSchedules.handle_payment(
          %Stripe.Session{
            client_reference_id: "proposal_#{proposal.id}",
            metadata: %{"paying_for" => payment_schedule.id}
          },
          PicselloWeb.Helpers
        )

      assert {:ok, _} = result

      assert %{paid_at: %DateTime{}} = payment_schedule |> Repo.reload!()

      assert_receive {:delivered_email, %{to: [nil: "photographer@example.com"]}}
      assert_receive {:delivered_email, %{to: [nil: "elizabeth-lead@example.com"]}}
    end

    test "it does not update paid_at if already paid", %{lead: lead, proposal: proposal} do
      paid_at = DateTime.utc_now() |> DateTime.truncate(:second)

      payment_schedule =
        insert(:payment_schedule,
          job: lead,
          price: ~M[5000]USD,
          paid_at: paid_at
        )

      result =
        PaymentSchedules.handle_payment(
          %Stripe.Session{
            client_reference_id: "proposal_#{proposal.id}",
            metadata: %{"paying_for" => payment_schedule.id}
          },
          PicselloWeb.Helpers
        )

      assert {:ok, :already_paid} = result

      assert %{paid_at: ^paid_at} = payment_schedule |> Repo.reload!()
    end
  end

  describe "paid_amount/1" do
    test "returns the amount that has been paid", %{
      lead: lead,
      proposal: proposal,
      payment_schedule: payment_schedule
    } do
      PaymentSchedules.handle_payment(
        %Stripe.Session{
          client_reference_id: "proposal_#{proposal.id}",
          metadata: %{"paying_for" => payment_schedule.id}
        },
        PicselloWeb.Helpers
      )

      assert PaymentSchedules.paid_amount(lead) == 5000
    end

    test "returns 0 when no payment has been executed yet", %{lead: lead} do
      assert PaymentSchedules.paid_amount(lead) == 0
    end
  end

  describe "owed_price/1" do
    test "returns 0 when you have no amount in owed-queue", %{
      lead: lead,
      proposal: proposal,
      payment_schedule: payment_schedule
    } do
      PaymentSchedules.handle_payment(
        %Stripe.Session{
          client_reference_id: "proposal_#{proposal.id}",
          metadata: %{"paying_for" => payment_schedule.id}
        },
        PicselloWeb.Helpers
      )

      assert PaymentSchedules.owed_amount(lead) == 0
    end

    test "returns the owed amount", %{lead: lead} do
      assert PaymentSchedules.owed_amount(lead) == 5000
    end
  end

  describe "payment_schedules_count/1" do
    test "returns 1 when count of payment_schedules in any lead is 1", %{lead: lead} do
      assert PaymentSchedules.payment_schedules_count(lead) == 1
    end

    test "returns 2 when count of payment_schedules in any lead is 2 and so on", %{lead: lead} do
      insert(:payment_schedule,
        job: lead,
        price: ~M[5000]USD
      )

      assert PaymentSchedules.payment_schedules_count(lead) == 2
    end
  end
end
