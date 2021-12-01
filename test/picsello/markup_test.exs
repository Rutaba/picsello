defmodule Picsello.MarkupTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Markup}

  describe "changeset" do
    test "works with percent values" do
      assert %{value: 100.0} =
               insert(:markup) |> Markup.changeset(%{"value" => "100%"}) |> Repo.update!()
    end

    test "works with int values" do
      assert %{value: 4.0} =
               build(:markup, product: insert(:product), organization: insert(:organization))
               |> Markup.changeset(%{"value" => "4"})
               |> Ecto.Changeset.apply_changes()
               |> Repo.insert!()
    end
  end
end
