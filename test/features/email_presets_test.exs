# vim: ts=27:
defmodule Picsello.EmailPresetsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Picsello.Mock.mock_google_sheets(%{
      "wedding!A1:E4" => """
      state	subject lines	copy	email template name
      lead	hear them bells a ringin'	Hi	bells
      lead	You owe me {{invoice_amount}}, {{client_first_name}}.	Gimme a call at <strong>{{photographer_cell}}</strong>.	please
      job	thanks for the money!	Dollar bills y'all.	stacking paper
      post shoot	that was fun!	Good job everybody.	good job
      """
    })

    Picsello.Workers.SyncEmailPresets.perform(%{
      args: %{
        column_map: %{
          "copy" => :body_template,
          "email template name" => :name,
          "state" => :job_state,
          "subject lines" => :subject_template
        },
        sheet_id: "whatever",
        type_ranges: %{"wedding" => "wedding!A1:E4"}
      }
    })

    [
      lead:
        insert(:lead,
          user: user,
          type: "wedding",
          client: [name: "Elizabeth Taylor"]
        )
    ]
  end

  feature "Photographer chooses from wedding lead presets", %{
    session: session,
    lead: lead,
    user: user
  } do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Send message"))
    |> find(
      select("Select email preset"),
      &(&1
        |> assert_has(css("option", count: 3))
        |> assert_has(css("option", text: "bells"))
        |> assert_has(css("option", text: "please"))
        |> click(css("option", text: "please")))
    )
    |> assert_has(css("#editor strong", text: user.onboarding.phone))
    |> assert_value(text_field("Subject line"), "You owe me , Elizabeth.")
    |> wait_for_enabled_submit_button()
    |> click(button("Send Email"))
  end
end
