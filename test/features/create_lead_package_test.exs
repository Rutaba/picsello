defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package}

  setup :onboarded
  setup :authenticated

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  @add_package_button testid("add-package-from-shoot")
  @price_text_field text_field("Package Price")

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
    |> fill_in(@price_text_field, with: "$100")
    |> scroll_into_view(css("#package_pricing_is_enabled_true"))
    |> click(radio_button("Gallery includes Print Credits"))
    |> find(
      text_field("package[print_credits]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$30"))
    )
    |> scroll_into_view(css("#download_is_enabled_true"))
    |> click(css("#download_status_limited"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "2"))
    )
    |> scroll_into_view(css("#download_is_custom_price"))
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(css("#download_is_buy_all"))
    |> find(
      text_field("download[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$10"))
    )
    |> assert_has(definition("Total", text: "$100.00"))
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

    base_price = Money.new(10_000)
    download_each_price = Money.new(200)
    buy_all = Money.new(1000)
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

  feature "user with package templates sees them", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    template1 =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding"
      )

    template2 =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "lame wedding"
      )

    insert(:package_payment_schedule, %{package: template1})
    insert(:package_payment_schedule, %{package: template2})
    insert(:package_template, user: user, job_type: "other")

    selected_card = css("[data-testid='template-card'].bg-gray-100")

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> assert_has(testid("template-card", count: 2))
    |> find(button("New Package"), &assert(!Element.attr(&1, :disabled)))
    |> find(button("Use template"), &assert(Element.attr(&1, :disabled)))
    |> click(testid("template-card", text: "best wedding"))
    |> find(button("Customize"), &assert(!Element.attr(&1, :disabled)))
    |> find(button("Use template"), &assert(!Element.attr(&1, :disabled)))
    |> click(testid("template-card", text: "best wedding"))
    |> find(button("New Package"), &assert(!Element.attr(&1, :disabled)))
    |> find(button("Use template"), &assert(Element.attr(&1, :disabled)))
    |> click(testid("template-card", text: "best wedding"))
    |> find(selected_card, &assert_text(&1, "best wedding"))
    |> click(testid("template-card", text: "lame wedding"))
    |> find(selected_card, &assert_text(&1, "lame wedding"))
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
      |> wait_for_enabled_submit_button(text: "Next")
      |> package_payment_screen()
    end)
    |> assert_text("Wedding Deluxe")
    |> assert_text("Selected contract: Picsello Default Contract")
  end

  feature "user with package templates uses one as-is", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    base_price = Money.new(10_000)
    download_each_price = Money.new(200)
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

    insert(:package_payment_schedule, %{package: template})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(testid("template-card"))
    |> click(button("Use template"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
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
    |> assert_value(@price_text_field, "$100.00")
    |> assert_value(text_field("download_count"), "1")
    |> assert_value(text_field("download_each_price"), "$50.00")
    |> fill_in(@price_text_field, with: "200")
    |> package_payment_screen()
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    template_id = template.id
    base_price = Money.new(20_000)

    assert %Package{
             name: "Wedding Deluxe",
             job_type: nil,
             shoot_count: 2,
             description: "<p>desc</p>",
             base_price: ^base_price,
             download_count: 1,
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

    assert %Picsello.Contract{name: "My job custom contract", contract_template_id: ^contract_template_id} =
             lead.package.contract
  end

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: " ")
    |> assert_has(css("label", text: "Title can't be blank"))
    |> fill_in_quill(" ")
    |> assert_has(css("label", text: "Description can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in_quill("My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_disabled_submit(text: "Next")
    |> fill_in(@price_text_field, with: " ")
    |> scroll_into_view(css("#package_pricing_is_enabled"))
    |> scroll_into_view(css("#package_pricing_is_enabled_true"))
    |> click(radio_button("Gallery includes Print Credits"))
    |> find(
      text_field("package[print_credits]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: ""))
    )
    |> scroll_into_view(css("#download_is_enabled_true"))
    |> click(css("#download_status_limited"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: " "))
    )
    |> scroll_into_view(css("#download_is_custom_price"))
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: " "))
    )
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(css("#download_is_buy_all"))
    |> find(
      text_field("download[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: " "))
    )
    |> assert_has(definition("Total", text: "$0.00"))
    |> assert_disabled_submit()
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
    |> fill_in(@price_text_field, with: "$100")
    |> click(testid("step-number", text: "Step 2"))
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_value(text_field("Title"), "Wedding Deluxe")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_value(@price_text_field, "$100.00")
  end
end
