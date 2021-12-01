defmodule Picsello.MarkupTest do
  use Picsello.DataCase, async: true

  alias Picsello.Markup

  describe "changeset" do
    test "works with percent values" do
      assert %{value: 100.0} =
               build(:markup)
               |> Markup.changeset(%{"value" => "100%"})
               |> Ecto.Changeset.apply_changes()
    end
  end
end
