defmodule Picsello.EditLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo

  setup :onboarded
  setup :authenticated

  @price_text_field text_field("Creative Session Price")

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        package: %{
          name: "My Greatest Package",
          description: "<p>My custom description</p>",
          shoot_count: 2,
          buy_all: 100,
          print_credits: 200,
          base_price: 100,
          download_each_price: 0
        },
        shoots: [%{}, %{}]
      })

    [lead: lead, session: session]
  end

  feature "user edits a package", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("card-Package details"), &click(&1, button("Edit")))
    |> assert_has(button("Cancel"))
    |> assert_text("Edit Package: Provide Details")
    |> assert_value(text_field("Title"), "My Greatest Package")
    |> fill_in(text_field("Title"), with: "My updated package")
    |> assert_value(select("# of Shoots"), "2")
    |> click(css("div.ql-editor"))
    |> find(select("# of Shoots"), &click(&1, option("1")))
    |> assert_has(css("label", text: "# of Shoots must be greater than or equal to 2"))
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> click(button("Next"))
    |> assert_text("Edit Package: Set Pricing")
    |> assert_value(@price_text_field, "$1.00")
    |> fill_in(@price_text_field, with: "2.00")
    |> assert_has(radio_button("Do not charge for downloads", checked: true))
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> find(testid("card-Package details"), &assert_text(&1, "My updated package"))

    package = lead |> Repo.preload(:package) |> Map.get(:package)

    form_fields =
      ~w(base_price job_type name gallery_credit download_count download_each_price shoot_count buy_all print_credits)a

    updated =
      %{
        package
        | name: "My updated package",
          description: "<p>indescribably great.</p>",
          base_price: %Money{amount: 200},
          download_each_price: %Money{amount: 0},
          buy_all: %Money{amount: 100},
          print_credits: %Money{amount: 200}
      }
      |> Map.take([:id | form_fields])

    assert ^updated = Repo.reload!(package) |> Map.take([:id | form_fields])
  end
end
