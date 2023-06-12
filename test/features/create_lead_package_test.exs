defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package}

  setup :onboarded
  setup :authenticated

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  @add_package_button testid("add-package-from-shoot")

  def fill_in_package_form(session) do
    session
    |> assert_text("Add a Package: Provide Details")
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in_quill("My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> find(button("Next"), &assert(Element.attr(&1, :disabled)))
    |> fill_in(css("#form-pricing_base_price"), with: "$1000")
    |> scroll_into_view(css("[phx-click='edit-print-credits']"))
    |> click(button("Edit settings", at: 0))
    |> click(radio_button("Gallery includes Print Credits"))
    |> find(
      text_field("package[print_credits]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$30"))
    )
    |> click(css("[href='/images/icons.svg#close-x']", at: 1))
    |> scroll_into_view(css("[phx-click='edit-digitals']"))
    |> click(button("Edit settings", at: 1))
    |> click(css("#download_status_limited"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "2"))
    )
    |> click(css("[href='/images/icons.svg#close-x']", at: 1))
    |> click(button("Edit image price"))
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$50"))
    )
    |> click(css("[href='/images/icons.svg#close-x']", at: 1))
    |> click(button("Edit upsell options"))
    |> click(css("#download_is_buy_all"))
    |> find(
      text_field("download[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$250"))
    )
  end

  defp package_payment_screen(session) do
    session
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_has(testid("remaining-to-collect", text: "$0.00"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
  end

  feature "user without package templates creates a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> fill_in_package_form()
    |> package_payment_screen()
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    base_price = Money.new(100_000)
    download_each_price = Money.new(5000)
    buy_all = Money.new(25_000)
    print_credits = Money.new(3000)

    description = "<p>My greatest wedding package</p>"

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             description: ^description,
             base_price: ^base_price,
             download_count: 2,
             buy_all: ^buy_all,
             print_credits: ^print_credits,
             download_each_price: ^download_each_price
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user with package templates creates new package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    insert(:package_template,
      user: user,
      job_type: "wedding",
      name: "best wedding"
    )

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> within_modal(fn modal ->
      modal
      |> click(button("New Package"))
      |> fill_in_package_form()
      |> package_payment_screen()
    end)
    |> assert_text("Wedding Deluxe")
    |> assert_text("Selected contract: Picsello Default Contract")
  end

  feature "user with package templates uses one as-is", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    base_price = Money.new(10_000)
    download_each_price = Money.new(300)
    buy_all = Money.new(5000)
    print_credits = Money.new(1500)

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding",
        shoot_count: 1,
        description: "desc",
        base_price: base_price,
        buy_all: buy_all,
        print_credits: print_credits,
        download_count: 1,
        download_each_price: download_each_price
      )

    template_2 =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "wedding",
        shoot_count: 1,
        description: "desc",
        base_price: base_price,
        buy_all: buy_all,
        print_credits: print_credits,
        download_count: 1,
        download_each_price: download_each_price
      )

    insert(:package_payment_schedule, %{package: template})
    insert(:package_payment_schedule, %{package: template_2})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(testid("template-card", count: 2, at: 0))
    |> click(button("Use template"))
    |> assert_text("best wedding")

    template_id = template.id

    assert %Package{
             name: "best wedding",
             job_type: nil,
             shoot_count: 1,
             description: "desc",
             base_price: ^base_price,
             buy_all: ^buy_all,
             print_credits: ^print_credits,
             download_count: 1,
             download_each_price: ^download_each_price,
             package_template_id: ^template_id
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user with package templates with contract uses one as-is", %{
    session: session,
    user: user
  } do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding"
      )

    insert(:package_payment_schedule, %{package: template})

    contract_template =
      insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")

    insert(:contract, package_id: template.id, contract_template_id: contract_template.id)

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(testid("template-card"))
    |> click(button("Use template"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("best wedding")
    |> assert_text("Selected contract: Contract 1")

    lead = lead |> Repo.reload() |> Repo.preload(package: [:contract, :questionnaire_template])
    assert %Package{name: "best wedding"} = lead.package

    contract_template_id = contract_template.id

    assert %Picsello.Contract{name: "Contract 1", contract_template_id: ^contract_template_id} =
             lead.package.contract
  end

  feature "user customizes package template", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})
    insert(:global_gallery_settings, organization: user.organization)

    base_price = Money.new(10_000)
    download_each_price = Money.new(5000)
    buy_all = Money.new(7000)
    print_credits = Money.new(0)

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding",
        shoot_count: 2,
        description: "desc",
        base_price: base_price,
        buy_all: buy_all,
        print_credits: print_credits,
        download_count: 1,
        download_each_price: download_each_price
      )

    session
    |> visit("/galleries/settings?section=digital_pricing")
    |> scroll_into_view(css("#gallery_download_each_price"))
    |> fill_in(css("#gallery_download_each_price"), with: 500)
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(testid("template-card"))
    |> click(button("Customize"))
    |> assert_value(text_field("Title"), "best wedding")
    |> assert_value(select("# of Shoots"), "2")
    |> focus_quill()
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_value(css("#form-pricing_base_price"), "$100.00")
    |> scroll_into_view(css("[phx-click='edit-discounts']"))
    |> click(css("[phx-click='edit-discounts']"))
    |> scroll_into_view(css("#multiplier_is_enabled"))
    |> click(css("#multiplier_is_enabled"))
    |> scroll_into_view(css("#multiplier_discount_base_price"))
    |> assert_disabled(css("#multiplier_discount_print_credits"))
    |> assert_disabled(css("#multiplier_discount_digitals"))
    |> scroll_into_view(css("[phx-click='edit-discounts']"))
    |> click(css("[phx-click='edit-discounts']"))
    |> scroll_into_view(css("[phx-click='edit-print-credits']"))
    |> click(css("[phx-click='edit-print-credits']"))
    |> scroll_into_view(css("#package_pricing_is_enabled_true"))
    |> click(css("#package_pricing_is_enabled_true"))
    |> find(
      text_field("package[print_credits]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> click(css("#package_pricing_print_credits_include_in_total"))
    |> click(css("[phx-click='edit-print-credits']"))
    |> scroll_into_view(css("[phx-click='edit-digitals']"))
    |> click(button("Edit settings", at: 1))
    |> scroll_into_view(css("#download_digitals_include_in_total"))
    |> click(css("#download_digitals_include_in_total"))
    |> fill_in(css("#download_count"), with: 2)
    |> click(css("[phx-click='edit-digitals']"))
    |> click(button("Edit image price"))
    |> scroll_into_view(css("#download_each_price"))
    |> fill_in(css("#download_each_price"), with: 0.0)
    |> assert_text("greater than two")
    |> fill_in(css("#download_each_price"), with: 2.0)
    |> fill_in(css("#download_each_price"), with: 2.2)
    |> assert_has(css("div", text: "greater than two", count: 0))
    |> click(css("[phx-click='edit-digitals']"))
    |> click(button("Edit upsell options"))
    |> scroll_into_view(css("#download_buy_all"))
    |> find(
      text_field("download[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> assert_text("greater than digital image price")
    |> find(
      text_field("download[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$4"))
    )
    |> assert_has(css("div", text: "greater than digital image price", count: 0))
    |> click(css("[phx-click='edit-digitals']"))
    |> scroll_into_view(css("[phx-click='edit-discounts']"))
    |> click(css("[phx-click='edit-discounts']"))
    |> scroll_into_view(css("#multiplier_is_enabled"))
    |> scroll_into_view(css("#multiplier_discount_base_price"))
    |> click(css("#multiplier_discount_base_price"))
    |> click(css("#multiplier_discount_print_credits"))
    |> click(css("#multiplier_discount_digitals"))
    |> scroll_into_view(css("[phx-click='edit-discounts']"))
    |> click(css("[phx-click='edit-discounts']"))
    |> scroll_into_view(testid("sumup-grid"))
    |> find(testid("sumup-grid"), fn row ->
      row
      |> assert_has(css("span", text: "Creative Session Fee"))
      |> assert_has(css("span", text: "with 10% discount", count: 3))
      |> assert_has(css("span", text: "+$100.00"))
      |> assert_has(css("span", text: "-$10.00"))
      |> assert_has(css("span", text: "Professional Print Credit"))
      |> assert_has(css("span", text: "+$2.00"))
      |> assert_has(css("span", text: "-$0.20"))
      |> assert_has(css("span", text: "Digital Collection"))
      |> assert_has(css("span", text: "+$4.40"))
      |> assert_has(css("span", text: "-$0.44"))
      |> assert_has(css("span", text: "Package Total"))
      |> assert_has(css("span", text: "$95.76"))
    end)
    |> scroll_into_view(css("[phx-click='edit-discounts']"))
    |> click(css("[phx-click='edit-discounts']"))
    |> scroll_into_view(css("#multiplier_percent"))
    |> find(css("#multiplier_percent"), &click(&1, option("20%")))
    |> find(css("#multiplier_sign"), &click(&1, option("Surcharge")))
    |> scroll_into_view(testid("sumup-grid"))
    |> find(testid("sumup-grid"), fn row ->
      row
      |> assert_has(css("span", text: "Creative Session Fee"))
      |> assert_has(css("span", text: "with 20% surcharge", count: 3))
      |> assert_has(css("span", text: "+$100.00"))
      |> assert_has(css("span", text: "+$20.00"))
      |> assert_has(css("span", text: "Professional Print Credit"))
      |> assert_has(css("span", text: "+$2.00"))
      |> assert_has(css("span", text: "+$0.40"))
      |> assert_has(css("span", text: "Digital Collection"))
      |> assert_has(css("span", text: "+$4.40"))
      |> assert_has(css("span", text: "+$0.88"))
      |> assert_has(css("span", text: "Package Total"))
      |> assert_has(css("span", text: "$127.68"))
    end)
    |> package_payment_screen()
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    template_id = template.id
    download_each_price = Money.new(220)
    buy_all = Money.new(400)
    print_credits = Money.new(200)

    assert %Package{
             name: "Wedding Deluxe",
             job_type: nil,
             shoot_count: 2,
             description: "<p>desc</p>",
             base_price: ^base_price,
             download_count: 2,
             buy_all: ^buy_all,
             print_credits: ^print_credits,
             download_each_price: ^download_each_price,
             package_template_id: ^template_id
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user customizes package template that contains contract", %{
    session: session,
    user: user
  } do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding"
      )

    contract_template =
      insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")

    insert(:contract, package_id: template.id, contract_template_id: contract_template.id)

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(testid("template-card"))
    |> click(button("Customize"))
    |> assert_value(text_field("Title"), "best wedding")
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> package_payment_screen()
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    template_id = template.id

    lead =
      lead
      |> Repo.reload()
      |> Repo.preload(package: [:contract, :questionnaire_template])

    assert %Package{name: "Wedding Deluxe", package_template_id: ^template_id} = lead.package

    contract_template_id = contract_template.id

    assert %Picsello.Contract{
             name: "My job custom contract",
             contract_template_id: ^contract_template_id
           } = lead.package.contract
  end

  feature "user navigates back and forth on steps", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_disabled_submit()
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in_quill("My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_disabled_submit()
    |> fill_in(text_field("package[base_price]"), with: "$100")
    |> click(testid("step-number", text: "Step 2"))
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_value(text_field("Title"), "Wedding Deluxe")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> fill_in(text_field("package[base_price]"), with: "$100")
  end
end
