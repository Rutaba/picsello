defmodule Picsello.SignInTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature
  import Wallaby.Query

  feature "users views welcome page", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css(".phx-hero", text: "Welcome"))
  end
end
