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

  describe "onboarding_changeset" do
    test "validates website" do
      assert [["invalid scheme ftp"], nil, nil, ["invalid host bad!.hostname"]] =
               for(
                 url <- [
                   "ftp://example.com",
                   "example.com",
                   "example.com/my-profile",
                   "https://bad!.hostname"
                 ],
                 do:
                   %User{}
                   |> User.onboarding_changeset(%{onboarding: %{website: url}})
                   |> errors_on()
                   |> get_in([:onboarding, :website])
               )
    end
  end
end
