defmodule PicselloWeb.PackageDetailsComponentTest do
  use Picsello.DataCase, async: true
  alias PicselloWeb.JobLive.PackageDetailsComponent
  alias Picsello.Package
  alias Phoenix.LiveView.Socket

  describe "assign :shoot_count_options" do
    def shoot_count_options(shoot_count) do
      {:ok, %{assigns: %{shoot_count_options: shoot_count_options}}} =
        PackageDetailsComponent.update([], %Socket{
          assigns: %{
            shoot_count: shoot_count,
            package: %Package{id: 1},
            current_user: insert(:user)
          }
        })

      shoot_count_options
    end

    test "1..5 when or or 1 shoots" do
      for(count <- [0, 1], do: assert([1, 2, 3, 4, 5] = shoot_count_options(count)))
    end

    test "disables numbers less than shoot count" do
      assert [[key: 1, value: 1, disabled: true], 2, 3, 4, 5] = shoot_count_options(2)

      assert [[key: 1, value: 1, disabled: true], [key: 2, value: 2, disabled: true], 3, 4, 5] =
               shoot_count_options(3)
    end
  end
end
