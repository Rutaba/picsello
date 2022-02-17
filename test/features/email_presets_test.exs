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
      lead	Let's do this {{client_first_name}}.	Gimme a call at {{photographer_cell}}.	please
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
        |> assert_has(css("option", count: 2))
        |> assert_has(css("option", text: "bells"))
        |> assert_has(css("option", text: "please"))
        |> click(css("option", text: "please")))
    )
    |> find(css("#editor"), &assert_text(&1, "Gimme a call at #{user.onboarding.phone}"))
    |> assert_value(text_field("Subject line"), "Let's do this Elizabeth.")
  end
end
