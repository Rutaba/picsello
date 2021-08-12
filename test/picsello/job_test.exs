defmodule Picsello.JobTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Job, Repo}

  describe "create_changeset" do
    test "works with client_id" do
      %{id: client_id} = insert(:client)

      Job.create_changeset(%{type: "family", client_id: client_id}) |> Repo.insert!()
    end

    test "error when wrong client_id" do
      assert {:error, changeset} =
               Job.create_changeset(%{type: "family", client_id: 9000})
               |> Repo.insert()

      assert {"does not exist", _} = changeset.errors[:client]
    end

    test "works with client attributes" do
      %{id: organization_id} = insert(:organization)

      client_params = params_for(:client, %{organization_id: organization_id})
      Job.create_changeset(%{type: "family", client: client_params}) |> Repo.insert!()
    end

    test "error when wrong client attributes" do
      assert {:error, changeset} =
               Job.create_changeset(%{type: "family", client: %{}})
               |> Repo.insert()

      refute changeset.changes[:client].errors |> Enum.empty?()
    end
  end

  describe "lead?" do
    test "true when there are no paid deposits on this jobs proposals" do
      job = insert(:job)

      assert Job.lead?(job)

      assert 1 = Job.leads() |> Repo.aggregate(:count)
      assert 0 = Job.not_leads() |> Repo.aggregate(:count)

      insert(:proposal, %{job: job, deposit_paid_at: nil})

      assert Job.lead?(job)

      assert 1 = Job.leads() |> Repo.aggregate(:count)
      assert 0 = Job.not_leads() |> Repo.aggregate(:count)

      insert(:proposal, %{job: job, deposit_paid_at: DateTime.utc_now()})

      refute Job.lead?(job)

      assert 0 = Job.leads() |> Repo.aggregate(:count)
      assert 1 = Job.not_leads() |> Repo.aggregate(:count)
    end
  end
end
