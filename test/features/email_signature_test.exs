defmodule Picsello.EmailSignatureTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user)

    insert(:brand_link, user: user)
    insert(:brand_link, user: user, use_publicly?: true, show_on_profile?: true, active?: true)

    [lead: lead]
  end

  feature "user changes email signature", %{session: session} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Brand"))
    |> assert_inner_text(testid("signature-preview"), "MJCamera User Group(918) 555-1234")
    |> assert_has(testid("marketing-links", count: 1))
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> assert_has(css("a[href='photos.example.com']"))
    end)
    |> click(button("Change signature"))
    |> click(css("label", text: "Show your phone number?"))
    |> fill_in_quill("This is my signature")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Email signature saved")
    |> assert_inner_text(testid("signature-preview"), "MJCamera User GroupThis is my signature")
  end

  feature "user sends email with signature", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Send message"))
    |> fill_in(text_field("Subject line"), with: "Hello")
    |> fill_in_quill("This is the body")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Send Email"))
    |> assert_text("Email sent")

    assert_receive {:delivered_email, email}

    assert "--MJCamera User Group(918) 555-1234" ==
             email |> email_substitutions |> Map.get("email_signature") |> Floki.text(deep: true)
  end
end
