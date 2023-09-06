defmodule Picsello.UserManagesPackageTemplatesTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package, JobType}
  import Ecto.Query

  setup :onboarded
  setup :authenticated

  setup do
    Mix.Tasks.ImportQuestionnaires.run(nil)
  end

  defp payment_screen(session) do
    session
    |> click(button("Next"))
    |> scroll_into_view(testid("select-preset-type"))
    |> find(select("custom_payments_schedule_type"), &click(&1, option("2 split payments")))
    |> scroll_into_view(testid("preset-summary"))
    |> fill_in(css("#custom_payments_payment_schedules_0_percentage"), with: "50")
    |> fill_in(css("#custom_payments_payment_schedules_1_percentage"), with: "50")
    |> assert_has(testid("preset-summary", text: "50% To Book, 50% Day Before"))
    |> assert_has(testid("balance-to-collect", text: "$130.00 (100%)"))
    |> assert_has(testid("payment-count-card", count: 2))
    |> find(
      select("custom_payments_payment_schedules_0_due_interval"),
      &assert_text(&1, "To Book")
    )
    |> find(
      select("custom_payments_payment_schedules_1_due_interval"),
      &assert_text(&1, "Day Before")
    )
    |> assert_has(testid("remaining-to-collect", text: "$0.00 (0.0%)"))
    |> click(radio_button("Fixed amount", checked: false))
    |> fill_in(css("#custom_payments_payment_schedules_0_price"), with: "60.00")
    |> fill_in(css("#custom_payments_payment_schedules_1_price"), with: "60.00")
    |> assert_has(testid("remaining-to-collect", text: "$10.00"))
    |> click(css("#custom_payments_payment_schedules_1_interval_false", checked: false))
    |> scroll_into_view(testid("select-preset-type"))
    |> find(
      css("#custom_payments_payment_schedules_1_price"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "70.00"))
    )
    |> scroll_into_view(testid("preset-summary"))
    |> assert_has(testid("preset-summary", text: "$60.00 to To Book, $70.00"))
  end

  defp edit_package_screen(session) do
    session
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_has(testid("payment-count-card", count: 3))
    |> find(
      select("custom_payments_payment_schedules_0_due_interval"),
      fn element -> assert_text(element, "To Book") end
    )
    |> find(
      select("custom_payments_payment_schedules_1_due_interval"),
      fn element -> assert_text(element, "6 Months Before") end
    )
    |> find(
      select("custom_payments_payment_schedules_2_due_interval"),
      fn element -> assert_text(element, "Week Before") end
    )
    |> assert_has(testid("remaining-to-collect", text: "$0.00"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
  end

  feature "navigate", %{session: session} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> assert_text("Meet Packages")
  end

  feature "view list with unlimited", %{session: session, user: user} do
    insert(:package_template,
      user: user,
      name: "Deluxe Template",
      download_each_price: %Money{amount: 0, currency: :USD}
    )

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> assert_text("Deluxe Template")
  end

  feature "view list with download price", %{session: session, user: user} do
    insert(:package_template,
      user: user,
      name: "Super Deluxe Template",
      download_count: 5,
      download_each_price: %Money{amount: 20, currency: :USD},
      print_credits: %Money{amount: 20, currency: :USD}
    )

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("intro-state-close-button"))
    |> find(testid("package-template-card"), &assert_text(&1, "Super Deluxe Template"))
    |> assert_text("$0.20/each")
  end

  feature "A newly added package's show-on-public-profile check is set to false as default", %{
    session: session
  } do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("intro-state-close-button"))
    |> click(button("Add package"))
    |> assert_text("Add a Package: Provide Details")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :new))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> assert_value(text_field("Image Turnaround Time"), "1")
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in_quill("My greatest wedding package")
    |> scroll_into_view(testid("modal-buttons"))
    |> click(css("label", text: "Event"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("Add a Package: Select Documents")
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> fill_in(css("#form-pricing_base_price"), with: "$100")
    |> scroll_into_view(testid("add-discount-surcharge"))
    |> click(button("Add a discount or surcharge"))
    |> scroll_into_view(css("#multiplier_is_enabled"))
    |> click(css("#multiplier_is_enabled"))
    |> fill_in(css("#multiplier_percent"), with: "30%")
    |> scroll_into_view(css("#multiplier_discount_base_price"))
    |> click(css("#multiplier_discount_base_price"))
    |> assert_text("-$30.00")
    |> click(option("Surcharge"))
    |> assert_text("+$30.00")
    |> scroll_into_view(testid("edit-digital-collection"))
    |> click(testid("edit-digital-collection"))
    |> click(css("#download_status_limited"))
    |> fill_in(css("#download_count"), with: 2)
    |> wait_for_enabled_submit_button()
    |> payment_screen()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_flash(:success, text: "The package has been successfully saved")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :index))

    package = Repo.all(Package) |> hd()

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             description: "<p>My greatest wedding package</p>",
             base_price: %Money{amount: 10_000},
             download_count: 2,
             download_each_price: %Money{amount: 5000},
             job_type: "event",
             package_template_id: nil
           } = package

    assert package.show_on_public_profile == false
  end

  feature "Add a package with default contract", %{session: session} do
    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("intro-state-close-button"))
    |> click(button("Add package"))
    |> assert_text("Add a Package: Provide Details")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :new))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in_quill("My greatest wedding package")
    |> scroll_into_view(testid("modal-buttons"))
    |> click(css("label", text: "Event"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("Add a Package: Select Documents")
    |> assert_has(link("Manage contracts"))
    |> assert_has(link("Manage questionnaires"))
    |> assert_has(testid("contracts-row", count: 1))
    |> assert_has(css("h3", text: "Picsello Default Contract"))
    |> assert_has(radio_button("contract_contract_template_id_1", checked: true))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> fill_in(css("#form-pricing_base_price"), with: "$130")
    |> wait_for_enabled_submit_button()
    |> payment_screen()
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_flash(:success, text: "The package has been successfully saved")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :index))

    package = Repo.all(Package) |> hd() |> Repo.preload(:contract)

    assert %Package{
             name: "Wedding Deluxe",
             job_type: "event"
           } = package

    assert %Picsello.Contract{
             name: "Picsello Default Contract"
           } = package.contract
  end

  feature "Edit the package with contract", %{session: session, user: user} do
    template =
      insert(:package_template, user: user, print_credits: %Money{amount: 20, currency: :USD})

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("edit-package-#{template.id}"))

    session
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :edit, template.id))
    |> within_modal(
      &(&1
        |> assert_text("Edit Package: Provide Details")
        |> assert_value(text_field("Title"), template.name)
        |> fill_in(text_field("Title"), with: "Wedding Super Deluxe")
        |> wait_for_enabled_submit_button()
        |> click(button("Next"))
        |> assert_text("Edit Package: Select Documents")
        |> click(button("Next"))
        |> assert_text("Edit Package: Set Pricing")
        |> scroll_into_view(testid("download"))
        |> Kernel.tap(fn modal ->
          refute Regex.match?(~r/downloads are valued/, Element.text(modal))
        end)
        |> edit_package_screen())
    )
    |> find(testid("package-template-card"), &assert_text(&1, "Wedding Super Deluxe"))
    |> assert_flash(:success, text: "The package has been successfully saved")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :index))

    form_fields =
      ~w(base_price job_type name download_count download_each_price shoot_count buy_all print_credits)a

    updated =
      %{
        template
        | name: "Wedding Super Deluxe",
          description: "<p>Package description</p>",
          download_each_price: %Money{amount: 300}
      }
      |> Map.take([:id | form_fields])

    package = Repo.all(Package) |> hd() |> Repo.preload(:contract)

    assert ^updated = package |> Map.take([:id | form_fields])

    %{id: contract_id} = Picsello.Contracts.default_contract(package)

    assert %Picsello.Contract{contract_template_id: ^contract_id} = package.contract
  end

  feature "edit with contract & questionnaire", %{session: session, user: user} do
    template = insert(:package_template, job_type: "wedding", user: user)

    contract_template =
      insert(:contract_template, user: user, job_type: "wedding", name: "Contract 1")

    insert(:contract, package_id: template.id, contract_template_id: contract_template.id)

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("edit-package-#{template.id}"))
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :edit, template.id))
    |> within_modal(
      &(&1
        |> assert_text("Edit Package: Provide Details")
        |> assert_value(text_field("Title"), template.name)
        |> fill_in(text_field("Title"), with: "Wedding Super Deluxe")
        |> wait_for_enabled_submit_button()
        |> click(button("Next"))
        |> assert_text("Edit Package: Select Documents")
        |> assert_has(link("Manage contracts"))
        |> assert_has(link("Manage questionnaires"))
        |> assert_has(testid("contracts-row", count: 2))
        |> assert_has(css("h3", text: "Contract 1"))
        |> assert_has(css("h3", text: "Picsello Default Contract"))
        |> click(radio_button("Contract 1"))
        |> click(radio_button("Picsello Default Contract"))
        |> click(button("Questionnaire"))
        |> click(radio_button("wedding"))
        |> click(button("Contract"))
        |> click(button("Next"))
        |> assert_text("Edit Package: Set Pricing")
        |> edit_package_screen())
    )
    |> find(testid("package-template-card"), &assert_text(&1, "Wedding Super Deluxe"))
    |> assert_flash(:success, text: "The package has been successfully saved")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :index))

    form_fields =
      ~w(base_price job_type name download_count download_each_price shoot_count buy_all print_credits)a

    updated =
      %{template | name: "Wedding Super Deluxe"}
      |> Map.take([:id | form_fields])

    package =
      Repo.all(Package)
      |> hd()
      |> Repo.preload(contract: :contract_template)

    assert ^updated = package |> Map.take([:id | form_fields])

    assert %Picsello.Contract{
             content: "the greatest job contract",
             name: "Contract 1",
             job_type: nil,
             contract_template: %{
               name: "Contract 1",
               job_type: "wedding"
             }
           } = package.contract

    session
    |> visit("/package_templates")
    |> click(testid("intro-state-close-button"))
    |> find(testid("package-template-card"), &assert_text(&1, "Wedding Super Deluxe"))
    |> click(testid("menu-btn-#{package.id}"))
    |> click(button("Duplicate"))
    |> within_modal(
      &(&1
        |> assert_text("Add a Package: Provide Details")
        |> fill_in(text_field("Title"), with: "Wedding Super Deluxe")
        |> wait_for_enabled_submit_button()
        |> click(button("Next"))
        |> assert_text("Add a Package: Select Documents")
        |> assert_has(link("Manage contracts"))
        |> assert_has(link("Manage questionnaires"))
        |> assert_has(testid("contracts-row", count: 2))
        |> assert_has(css("h3", text: "Contract 1"))
        |> assert_has(css("h3", text: "Picsello Default Contract"))
        |> click(radio_button("Contract 1"))
        |> click(radio_button("Picsello Default Contract"))
        |> click(button("Questionnaire"))
        |> click(radio_button("wedding"))
        |> click(button("Contract"))
        |> click(button("Next"))
        |> assert_text("Add a Package: Set Pricing")
        |> edit_package_screen())
    )
    |> assert_flash(:success, text: "The package has been successfully saved")

    assert Repo.all(Package) |> Enum.count() == 2
  end

  feature "Menu-btn archives/unarchives, duplicates, hide/shows the package and When no template exists, then show 'Missing package state'",
          %{session: session, user: user} do
    type = JobType.all() |> hd

    for name <- ~w(deluxe lame) do
      insert(:package_template,
        user: user,
        job_type: type,
        name: name
      )
    end

    package = Repo.all(Package) |> hd()

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> click(testid("intro-state-close-button"))
    |> click(testid("menu-btn-#{package.id}"))
    |> click(button("Archive"))
    |> assert_text("Are you sure you want to archive this package template?")
    |> click(button("Yes, archive"))
    |> assert_flash(:success, text: "The package has been archived")
    |> click(css(".archived-anchor-click"))
    |> assert_text("Archived Packages")
    |> scroll_to_bottom()
    |> click(button("Manage"))
    |> click(button("Archive"))
    |> assert_text("Are you sure you want to Un-archive this package template?")
    |> click(button("Yes, unarchive"))
    |> assert_flash(:success, text: "The package has been un-archived")

    assert package.show_on_public_profile == false

    package = Repo.all(Package) |> hd()

    session
    |> scroll_to_top()
    |> click(link("Package Templates"))
    |> click(testid("menu-btn-#{package.id}"))
    |> click(button("Show on public profile"))
    |> assert_text("Show on your Public Profile?")
    |> click(button("Great! Show on my Public Profile"))
    |> assert_flash(:success, text: "The package has been shown")

    package = Repo.get!(Package, package.id)

    assert package.show_on_public_profile == true

    session
    |> click(link("Package Templates"))
    |> scroll_to_top()
    |> click(testid("menu-btn-#{package.id}"))
    |> click(button("Hide on public profile"))
    |> assert_text("Hide on your Public Profile?")
    |> click(button("Hide on my Public Profile"))
    |> assert_flash(:success, text: "The package has been hidden")

    package = Repo.get!(Package, package.id)

    assert package.show_on_public_profile == false

    session
    |> click(link("Package Templates"))
    |> sleep(500)
    |> click(css(".newborn-anchor-click"))
    |> assert_text("Missing packages")
    |> assert_text(
      "You don't have any packages! Click add a package to get started. If you need help"
    )
  end

  feature "Pagination appears only when records are more than 4",
          %{session: session, user: user} do
    type = JobType.all() |> hd

    for name <- ~w(deluxe lame premium highfive yadix) do
      insert(:package_template,
        user: user,
        job_type: type,
        name: name
      )
    end

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> assert_has(button("Next"))

    from(pt in Package, where: pt.name in ["deluxe", "lame", "highfive"])
    |> Repo.delete_all()

    session
    |> click(testid("subnav-Settings"))
    |> click(link("Packages"))
    |> refute_has(button("Next"))
  end
end
