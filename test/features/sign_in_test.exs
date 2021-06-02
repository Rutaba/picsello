defmodule Picsello.SignInTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature
  import Wallaby.Query

  feature "user views sign up button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("button", text: "Sign Up"))
  end
end
