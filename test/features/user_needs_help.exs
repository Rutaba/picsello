defmodule Picsello.UserNeedsHelpTest do
  use Picsello.FeatureCase, async: true

  setup do
    user = insert(:user)

    [user: user]
  end

  setup :onboarded
  setup :authenticated

  feature "user has opened help scout using facade", %{session: session} do
    session
    |> click(css("#float-menu-help .help-scout-facade-circle"))
    |> refute_has(
      css("#float-menu-help .help-scout-facade-circle .toggle-content", visible: false)
    )
    |> click(css("#float-menu-help #help-scout-1"))
    |> assert_has(css("#float-menu-help", visible: false))
    |> focus_frame(css(".BeaconFabButtonFrame iframe"))
    |> click(css("#beacon-container button.is-fab-shown"))
    |> focus_parent_frame()
    |> assert_has(css("#float-menu-help", visible: true))

    # Had to reset the session here to reset the iframe
    session
    |> click(css("#float-menu-help .help-scout-facade-circle"))
    |> refute_has(
      css("#float-menu-help .help-scout-facade-circle .toggle-content", visible: false)
    )
    |> click(css("#float-menu-help #help-scout-2"))
    |> assert_has(css("#float-menu-help", visible: false))
    |> focus_frame(css(".BeaconFabButtonFrame iframe"))
    |> click(css("#beacon-container button.is-fab-shown"))
    |> focus_parent_frame()
    |> assert_has(css("#float-menu-help", visible: true))
  end

  feature "user has opened help scout using footer", %{session: session} do
    session
    |> click(css("#help-scout-footer"))
    |> assert_has(css("#float-menu-help", visible: false))
    |> focus_frame(css(".BeaconFabButtonFrame iframe"))
    |> click(css("#beacon-container button.is-fab-shown"))
    |> focus_parent_frame()
    |> assert_has(css("#float-menu-help", visible: true))
  end
end
