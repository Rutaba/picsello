defmodule Picsello.PaymentSchedulesTest do
  use Picsello.DataCase, async: true

  alias Picsello.{PaymentSchedules}

  describe "build_payment_schedules_for_lead/1" do
    test "returns list with deposit and remainder attributes" do
      %{id: lead_id} =
        lead =
        insert(:lead,
          package: %{shoot_count: 2, base_price: 2000},
          shoots: [%{starts_at: ~U[2029-09-30 19:00:00Z]}, %{starts_at: ~U[2039-09-30 19:00:00Z]}]
        )

      price = Money.new(1000)

      assert [
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
             ] = PaymentSchedules.build_payment_schedules_for_lead(lead)

      assert deposit_due |> DateTime.to_date() == DateTime.utc_now() |> DateTime.to_date()
    end
  end
end
