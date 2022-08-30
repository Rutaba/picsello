defmodule Picsello.EditLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo
  import Money.Sigils

  setup :onboarded
  setup :authenticated

  @price_text_field css("#form-pricing_base_price")

  setup %{session: session, user: %{organization: organization} = user} do
    organization |> Picsello.Organization.assign_stripe_account_changeset("123") |> Repo.update!()

    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    lead =
      insert(:lead, %{
        user: user,
        package: %{
          name: "My Greatest Package",
          description: "<p>My custom description</p>",
          shoot_count: 2,
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
    |> within_modal(fn modal ->
      modal
      |> assert_has(button("Cancel"))
      |> assert_text("Edit Package: Provide Details")
      |> assert_value(text_field("Title"), "My Greatest Package")
      |> fill_in(text_field("Title"), with: "My updated package")
      |> assert_value(select("# of Shoots"), "2")
      |> focus_quill()
      |> find(select("# of Shoots"), &click(&1, option("1")))
      |> assert_has(css("label", text: "# of Shoots must be greater than or equal to 2"))
      |> find(select("# of Shoots"), &click(&1, option("2")))
      |> wait_for_enabled_submit_button(text: "Next")
      |> take_screenshot()
      |> click(button("Next"))
      |> assert_text("Edit Package: Set Pricing")
      |> assert_value(@price_text_field, "$1.00")
      |> fill_in(@price_text_field, with: "2.00")
      |> assert_has(radio_button("Do not charge for downloads", checked: true))
      |> click(radio_button("Charge for downloads", checked: false))
      |> click(checkbox("Set my own download price"))
      |> find(
        text_field("download_each_price"),
        &(&1 |> Element.clear() |> Element.fill_in(with: "$4"))
      )
      |> scroll_into_view(css("#package_pricing_is_enabled"))
      |> click(checkbox("buy them all"))
      |> scroll_into_view(css("#download_buy_all"))
      |> fill_in(text_field("download_buy_all"), with: "$4")
      |> assert_text("Must be greater than digital image price")
      |> find(
        text_field("download_buy_all"),
        &(&1 |> Element.clear() |> Element.fill_in(with: "$5"))
      )
      |> wait_for_enabled_submit_button(text: "Save")
      |> click(button("Save"))
    end)
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
          base_price: ~M[200]USD,
          download_each_price: ~M[400]USD,
          buy_all: ~M[500]USD,
          print_credits: ~M[200]USD
      }
      |> Map.take([:id | form_fields])

    package = Repo.reload!(package)
    assert ^updated = package |> Map.take([:id | form_fields])

    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("card-Package details"), &click(&1, button("Edit")))
    |> assert_text("Edit Package: Provide Details")
    |> click(button("Next"))
    |> scroll_into_view(css("#package_pricing_is_enabled"))
    |> click(radio_button("Do not charge for downloads", checked: false))
    |> click(checkbox("package_pricing_is_enabled", checked: false))
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> find(testid("card-Package details"), &assert_text(&1, "My updated package"))

    updated =
      %{
        package
        | download_each_price: ~M[0]USD,
          buy_all: nil,
          print_credits: ~M[0]USD
      }
      |> Map.take([:id | form_fields])

    package = Repo.reload!(package)
    assert ^updated = package |> Map.take([:id | form_fields])
  end
end
