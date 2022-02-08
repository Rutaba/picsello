defmodule Picsello.EmailPresetTest do
  use Picsello.DataCase, async: true

  describe "for_job" do
    test "post_shoot" do
      organization = insert(:organization)
      package = insert(:package, organization: organization, shoot_count: 3)
      client = insert(:client, organization: organization)
      lead = insert(:lead, package: package, client: client, type: "wedding")
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(-100))
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(-100))
      insert(:shoot, job: lead, starts_at: DateTime.utc_now() |> DateTime.add(100))
      job = promote_to_job(lead)

      %{id: post_shoot_wedding_id} =
        insert(:email_preset, job_state: :post_shoot, job_type: "wedding")

      insert(:email_preset, job_state: :lead, job_type: "wedding")
      insert(:email_preset, job_state: :job, job_type: "wedding")

      insert(:email_preset, job_state: :post_shoot, job_type: "event")

      Picsello.EmailPreset
      |> Picsello.Repo.all()
      |> Enum.map(&Map.take(&1, [:id, :job_state, :job_type]))
      |> IO.inspect()

      assert [%Picsello.EmailPreset{id: ^post_shoot_wedding_id}] =
               Picsello.EmailPreset.for_job(job)
    end
  end
end
