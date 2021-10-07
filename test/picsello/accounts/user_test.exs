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

    test "requires switching_from_software if used_software_before" do
      assert %{} =
               %User{}
               |> User.onboarding_changeset(%{onboarding: %{used_software_before: false}})
               |> errors_on()

      assert %{onboarding: %{switching_from_software: ["can't be blank"]}} =
               %User{}
               |> User.onboarding_changeset(%{onboarding: %{used_software_before: true}})
               |> errors_on()
    end
  end

  describe "complete_onboarding_changeset" do
    test "marks the onboarding as complete" do
      user = insert(:user, onboarding: %{website: "http://example.com"})
      refute user |> User.onboarded?()

      assert %{onboarding: %{website: "http://example.com", completed_at: completed_at}} =
               user
               |> User.complete_onboarding_changeset()
               |> Repo.update!()

      assert completed_at
    end
  end

  describe "onboarded?" do
    test "false when partial onboarding data" do
      refute insert(:user, onboarding: %{website: "example.com"}) |> User.onboarded?()
    end

    test "true when onboarding completed_at" do
      assert insert(:user, onboarding: %{completed_at: DateTime.utc_now()}) |> User.onboarded?()
    end
  end

  describe "confirmed?" do
    test "siend up with google always true" do
      assert %User{sign_up_auth_provider: :google, confirmed_at: nil} |> User.confirmed?()

      assert %User{sign_up_auth_provider: :google, confirmed_at: DateTime.utc_now()}
             |> User.confirmed?()
    end

    test "siend up with password must have confirmed_at set" do
      refute %User{sign_up_auth_provider: :password, confirmed_at: nil} |> User.confirmed?()

      assert %User{sign_up_auth_provider: :password, confirmed_at: DateTime.utc_now()}
             |> User.confirmed?()
    end
  end
end
