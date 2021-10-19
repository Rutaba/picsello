defmodule Picsello.PackageTest do
  use Picsello.DataCase, async: true

  import Picsello.Factory
  alias Picsello.{Repo, Package}

  describe "update_changeset" do
    test "when specific package validates that shoot_count is greater than or equal to the current number of shoots" do
      %{package: package} =
        insert(:lead, %{package: %{}, shoots: [%{}, %{}]}) |> Repo.preload(:package)

      assert %{errors: []} = Package.update_changeset(package, %{shoot_count: 2})
      assert %{errors: [{:shoot_count, _}]} = Package.update_changeset(package, %{shoot_count: 1})
    end

    test "adds new template when package_template_id is new" do
      package =
        insert(:package)
        |> Package.update_changeset(%{"name" => "new template", "package_template_id" => "new"})
        |> Repo.update!()

      assert "new template" = package.name
    end
  end
end
