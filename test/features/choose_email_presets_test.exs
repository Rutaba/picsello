defmodule Picsello.ChooseEmailPresetsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query
  import Money.Sigils

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Picsello.Mock.mock_google_sheets(%{
      "wedding!A1:E4" => [
        ["state", "subject lines", "copy", "email template name"],
        ["lead", "hear them bells a ringin'", "Hi", "bells"],
        [
          "lead",
          "You owe me {{invoice_amount}}, {{{client_first_name}}}.",
          """
          Hey.

          There are <strong>loads</strong> of new lines in these.
          Wanna talk more about it? Gimme a call at <strong>{{photographer_cell}}</strong>.
          """,
          "please"
        ],
        ["job", "thanks for the money!", "Dollar bills y'all.", "stacking paper"],
        ["post shoot", "that was fun!", "Good job everybody.", "good job"]
      ]
    })

    Picsello.Workers.SyncEmailPresets.perform(%{
      args: %{
        column_map: %{
          "copy" => :body_template,
          "email template name" => :name,
          "state" => :state,
          "subject lines" => :subject_template
        },
        sheet_id: "whatever",
        type_ranges: %{"wedding" => "wedding!A1:E4"}
      }
    })

    lead =
      insert(:lead,
        user: user,
        type: "wedding",
        client: [name: "Elizab&th Taylor"],
        package: %{}
      )

    insert(:payment_schedule, job: lead, price: ~M[5000]USD)

    [lead: lead]
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
    |> assert_value(text_field("Subject line"), "You owe me $50.00, Elizab&th.")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> take_screenshot()
    |> click(button("Send Email"))
    |> assert_text("Email sent")

    assert_receive {:delivered_email,
                    %{
                      private: %{
                        send_grid_template: %{dynamic_template_data: %{"body" => html}}
                      }
                    }}

    assert ["loads", _] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("strong")
             |> Enum.map(&Floki.text/1)
  end
end
