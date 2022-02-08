# vim: ts=27:
defmodule Picsello.CalendarTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Picsello.Mock.mock_google_sheets(%{
      "wedding!A1:E4" => """
      state	subject lines	copy	email template name
      lead	hear them bells a ringin'	Hi	bells
      lead	you know you want to.	Please pay me.	please
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

    [lead: insert(:lead, user: user, type: "wedding")]
  end

  feature "Photographer chooses from wedding lead presets", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Send message"))
    |> find(select("Select email preset"))
    |> assert_has(css("option", count: 2))
    |> assert_has(css("option", text: "bells"))
    |> assert_has(css("option", text: "please"))
  end
end
