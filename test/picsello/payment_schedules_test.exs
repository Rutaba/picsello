defmodule Picsello.PaymentSchedulesTest do
  use Picsello.DataCase, async: true

  alias Picsello.{PaymentSchedules}

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
               label: "Payment",
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
                 label: "Payment Due in Full",
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
               label: "Standard Wedding Payment",
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
               label: "Advance Wedding Payment",
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
                 label: "Standard Payment",
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
end
