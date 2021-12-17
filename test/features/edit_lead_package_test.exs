defmodule Picsello.EditLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo

  setup :onboarded
  setup :authenticated

  @edit_package_button button("Package settings")

  setup %{session: session, user: user} do
    lead =
      insert(:lead, %{
        user: user,
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 2,
          base_price: 100
        },
        shoots: [%{}, %{}]
      })

    [lead: lead, session: session]
  end

  feature "user edits a package", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> click(@edit_package_button)
    |> assert_has(button("Cancel"))
    |> assert_text("Edit Package: Provide Details")
    |> assert_value(text_field("Title"), "My Package")
    |> assert_value(select("# of Shoots"), "2")
    |> assert_value(text_field("Description"), "My custom description")
    |> fill_in(text_field("Title"), with: "My Greatest Package")
    |> fill_in(text_field("Description"), with: "indescribably great.")
    |> find(select("# of Shoots"), &click(&1, option("1")))
    |> assert_has(css("label", text: "# of Shoots must be greater than or equal to 2"))
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> click(button("Next"))
    |> assert_text("Edit Package: Set Pricing")
    |> assert_value(text_field("Base Price"), "$1.00")
    |> fill_in(text_field("Base Price"), with: "2.00")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("My Greatest Package")

    package = lead |> Repo.preload(:package) |> Map.get(:package)

    form_fields =
      ~w(base_price description job_type name gallery_credit download_count download_each_price shoot_count)a

    updated =
      %{
        package
        | name: "My Greatest Package",
          description: "indescribably great.",
          base_price: %Money{amount: 200},
          download_each_price: %Money{amount: 5000}
      }
      |> Map.take([:id | form_fields])

    assert ^updated = Repo.reload!(package) |> Map.take([:id | form_fields])
  end
end
