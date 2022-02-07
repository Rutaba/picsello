defmodule Picsello.EmailSignatureTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user)

    [lead: lead]
  end

  feature "user changes email signature", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Brand"))
    |> assert_inner_text(testid("signature-preview"), "MJCamera User Group(918) 555-1234")
    |> click(button("Change signature"))
    |> click(css("label", text: "Show your phone number?"))
    |> click(css("div.ql-editor"))
    |> send_keys(["This is my signature"])
    |> click(button("Save"))
    |> assert_flash(:success, text: "Email signature saved")
    |> assert_inner_text(testid("signature-preview"), "MJCamera User GroupThis is my signature")
  end

  feature "user sends email with signature", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Send message"))
    |> fill_in(text_field("Subject line"), with: "Hello")
    |> click(css("div.ql-editor"))
    |> send_keys(["This is the body"])
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Send Email"))
    |> assert_text("Email sent")

    assert_receive {:delivered_email, email}

    assert "--MJCamera User Group(918) 555-1234" ==
             email |> email_substitutions |> Map.get("email_signature") |> Floki.text(deep: true)
  end
end
