defmodule Picsello.ChooseEmailPresetsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: false
  import Money.Sigils

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
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
    lead: lead
  } do
    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Send message"))
    |> fill_in(text_field("Subject line"), with: "You owe me $50.00, Elizab&th.")
    |> fill_in(css(".ql-editor"), with: "Test message")
    |> take_screenshot()
    |> click(button("Send Email"))
    |> assert_text("Email sent")

    assert_receive {:delivered_email,
                    %{
                      private: %{
                        send_grid_template: %{dynamic_template_data: %{"body" => html}}
                      }
                    }}

    assert ["Test message"] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("p")
             |> Enum.map(&Floki.text/1)
  end
end
