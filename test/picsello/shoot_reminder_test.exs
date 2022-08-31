defmodule Picsello.ShootReminderTest do
  use Picsello.DataCase, async: true
  alias Picsello.{ShootReminder, Repo, ClientMessage}
  require Ecto.Query

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    insert(:email_preset, state: :shoot_reminder, job_type: "mini", type: :job)

    [now: DateTime.utc_now()]
  end

  describe "deliver_all" do
    test "only delivers messages to clients that have shoots in the next 24 hours", %{now: now} do
      %{id: job1_id} =
        job1 =
        insert(:lead,
          type: "mini",
          package: %{
            shoot_count: 1
          },
          client: %{name: "John", email: "john@example.com"}
        )

      shoot1 =
        insert(:shoot, job: job1, starts_at: now |> DateTime.add(:timer.hours(23), :millisecond))

      job2 =
        insert(:lead,
          package: %{
            shoot_count: 2
          },
          type: "mini",
          client: %{name: "Jack", email: "jack@example.com"}
        )

      shoot2 =
        insert(:shoot, job: job2, starts_at: now |> DateTime.add(:timer.hours(-1), :millisecond))

      shoot3 =
        insert(:shoot, job: job2, starts_at: now |> DateTime.add(:timer.hours(25), :millisecond))

      job1 |> promote_to_job()
      job2 |> promote_to_job()

      :ok = ShootReminder.deliver_all(PicselloWeb.Helpers)

      assert [%{job_id: ^job1_id, scheduled: true, outbound: true}] = Repo.all(ClientMessage)

      assert_receive {:delivered_email, %{to: [nil: "john@example.com"]}}

      assert %{reminded_at: %DateTime{}} = shoot1 |> Repo.reload()
      assert %{reminded_at: nil} = shoot2 |> Repo.reload()
      assert %{reminded_at: nil} = shoot3 |> Repo.reload()
    end
  end
end
