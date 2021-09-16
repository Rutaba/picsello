defmodule Picsello.Accounts.UserTest do
  use Picsello.DataCase
  alias Picsello.Accounts.User

  describe "initials" do
    test "with one word name" do
      assert "BR" == %User{name: "brian"} |> User.initials()
    end

    test "with two word name" do
      assert "BD" == %User{name: "brian dunn"} |> User.initials()
    end

    test "with many word name" do
      assert "BD" == %User{name: "brian patrick hashrocket dunn"} |> User.initials()
    end
  end
end
