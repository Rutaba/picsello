defmodule Picsello.EditLeadPackageTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo

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
          print_credits: %Money{amount: 200, currency: :USD},
          base_price: %Money{amount: 100, currency: :USD},
          download_each_price: %Money{amount: 0, currency: :USD}
        },
        shoots: [%{}, %{}]
      })

    [lead: lead, session: session]
  end

  feature "user edits a package", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("card-Package details"), &click(&1, button("Edit")))
    |> click(button("Yes, edit package details"))
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
    |> scroll_to_bottom()
    |> scroll_into_view(testid("edit-digital-collection"))
    |> click(testid("edit-digital-collection"))
    |> click(css("#download_status_limited"))
    |> fill_in(css("#download_count"), with: 1)
    |> click(css("[phx-click='edit-digitals']"))
    |> click(css("[phx-click='edit-digitals']", at: 1))
    |> scroll_into_view(css("#download_each_price"))
    |> fill_in(css("#download_each_price"), with: 4)
    |> click(css("[phx-click='edit-digitals']"))
    |> click(css("[phx-click='edit-digitals']", at: 2))
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(css("#download_is_buy_all"))
    |> scroll_into_view(css("#download_buy_all"))
    |> fill_in(css("#download_buy_all"), with: 70)
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> scroll_into_view(testid("select-preset-type"))
    |> find(select("custom_payments_schedule_type"), &click(&1, option("2 split payments")))
    |> assert_has(testid("preset-summary", text: "50% To Book, 50% Day Before"))
    |> assert_has(testid("balance-to-collect", text: "$2.00 (100%)"))
    |> assert_has(testid("payment-count-card", count: 2))
    |> find(
      select("custom_payments_payment_schedules_0_due_interval"),
      &assert_text(&1, "To Book")
    )
    |> find(
      select("custom_payments_payment_schedules_1_due_interval"),
      &assert_text(&1, "Day Before Shoot")
    )
    |> assert_has(testid("remaining-to-collect", text: "$0.00 (0.0%)"))
    |> click(radio_button("Fixed amount", checked: false))
    |> scroll_into_view(css("#custom_payments_payment_schedules_0_price"))
    |> fill_in(css("#custom_payments_payment_schedules_0_price"), with: "0.50")
    |> fill_in(css("#custom_payments_payment_schedules_1_price"), with: "0.50")
    |> assert_has(testid("remaining-to-collect", text: "$1.00"))
    |> scroll_into_view(css("#custom_payments_payment_schedules_1_interval_false"))
    |> click(css("#custom_payments_payment_schedules_1_interval_false", checked: false))
    |> click(css("#payment-interval-1"))
    |> fill_in(css(".numInput.cur-year"), with: "2092")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("September")))
    |> click(css("[aria-label='September 1, 2092']"))
    |> scroll_into_view(testid("select-preset-type"))
    |> assert_has(testid("preset-summary", text: "$0.50 to To Book"))
    |> fill_in(css("#custom_payments_payment_schedules_1_price"), with: "1.50")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> find(testid("card-Package details"), &assert_text(&1, "My updated package"))

    package = lead |> Repo.preload(:package) |> Map.get(:package)

    form_fields =
      ~w(fixed schedule_type base_price job_type name gallery_credit download_count download_each_price shoot_count buy_all print_credits)a

    updated =
      %{
        package
        | name: "My updated package",
          description: "<p>indescribably great.</p>",
          base_price: %Money{amount: 200, currency: :USD},
          download_count: 1,
          download_each_price: %Money{amount: 400, currency: :USD},
          buy_all: %Money{amount: 7000, currency: :USD},
          print_credits: %Money{amount: 200, currency: :USD},
          schedule_type: "splits_2"
      }
      |> Map.take([:id | form_fields])

    package = Repo.reload!(package)
    assert ^updated = package |> Map.take([:id | form_fields])

    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("card-Package details"), &click(&1, button("Edit")))
    |> click(button("Yes, edit package details"))
    |> click(button("Next"))
    |> scroll_into_view(testid("print"))
    |> click(button("Edit settings", at: 0))
    |> click(radio_button("Gallery does not include Print Credits"))
    # |> scroll_into_view(css("#download_is_buy_all"))
    # |> click(css("#download_status_unlimited"))
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> find(testid("card-Package details"), &assert_text(&1, "My updated package"))

    updated =
      %{
        package
        | download_each_price: %Money{amount: 400, currency: :USD},
          buy_all: %Money{amount: 7000, currency: :USD},
          download_count: 1,
          print_credits: %Money{amount: 0, currency: :USD}
      }
      |> Map.take([:id | form_fields])

    package = Repo.reload!(package)
    assert ^updated = package |> Map.take([:id | form_fields])
  end
end
