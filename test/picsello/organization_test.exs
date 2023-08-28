defmodule Picsello.OrganizaitonTest do
  use Picsello.DataCase, async: true

  alias Picsello.Organization

  describe "registration_changeset" do
    test "slug - defaults" do
      assert {:ok, %{slug: "jane-s-photography"}} =
               Organization.registration_changeset(%Organization{}, %{
                 name: "  Jane's  Photography!"
               })
               |> Repo.insert()
    end

    test "slug - error name already exists" do
      insert(:organization, slug: "jane-s-photography")

      assert {:ok, %{slug: "jane-s-photography-2"}} =
               Organization.registration_changeset(%Organization{}, %{name: "Jane's Photography 2"})
               |> Repo.insert()
    end

    test "slug - adds a number on the end" do
      insert(:organization, slug: "jane-photography")

      assert {:ok, %{slug: "jane-photography-1"}} =
               Organization.registration_changeset(%Organization{}, %{}, "Jane")
               |> Repo.insert()
    end

    test "slug - increments a number on the end" do
      insert(:organization, slug: "jane-photography")
      insert(:organization, slug: "jane-photography-1")

      assert {:ok, %{slug: "jane-s-photography-3"}} =
               Organization.registration_changeset(%Organization{}, %{name: "Jane's Photography 3"})
               |> Repo.insert()
    end

    test "slug - can be overwritten" do
      assert {:ok, %{slug: "janes-photos"}} =
               Organization.registration_changeset(%Organization{}, %{
                 name: "Jane's Photography",
                 slug: "janes-photos"
               })
               |> Repo.insert()
    end
  end
end
