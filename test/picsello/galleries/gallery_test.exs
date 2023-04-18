defmodule Picsello.Galleries.GalleryTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Galleries.Gallery, Repo}

  describe "create_changeset" do
    test "name can't be blank" do
      changeset = Gallery.create_changeset(%Gallery{}, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "job_id can't be blank" do
      changeset = Gallery.create_changeset(%Gallery{}, %{})
      assert %{job_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "works with job_id" do
      %{id: job_id} = insert(:lead)

      Gallery.create_changeset(%Gallery{}, %{job_id: job_id, name: "12345Gallery"})
      |> Repo.insert!()
    end

    test "error with wrong job_id" do
      assert {:error, changeset} =
               Gallery.create_changeset(%Gallery{}, %{job_id: 777, name: "12345Gallery"})
               |> Repo.insert()

      assert {"does not exist", _} = changeset.errors[:job_id]
    end

    test "works with correct status" do
      changeset = Gallery.create_changeset(%Gallery{}, %{status: :active, job_id: 123})

      refute changeset.errors[:status]
    end

    test "error with wrong status" do
      changeset = Gallery.create_changeset(%Gallery{}, %{status: :draft, job_id: 123})

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end
end
