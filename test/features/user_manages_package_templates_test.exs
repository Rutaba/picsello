defmodule Picsello.UserManagesPackageTemplatesTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package, Packages.Download, JobType}

  setup :onboarded
  setup :authenticated

  feature "navigate", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("You don’t have any packages")
  end

  feature "view list with unlimited", %{session: session, user: user} do
    insert(:package_template,
      user: user,
      name: "Deluxe Template",
      download_count: 5,
      download_each_price: 0,
      buy_all: 20,
      print_credits: 20
    )

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("Deluxe Template")
    |> assert_text("All digital images included")
  end

  feature "view list with download price", %{session: session, user: user} do
    insert(:package_template,
      user: user,
      name: "Super Deluxe Template",
      download_count: 5,
      download_each_price: 20,
      buy_all: 20,
      print_credits: 20
    )

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("Super Deluxe Template")
    |> assert_has(definition("Digital images included", text: "5"))
    |> assert_text("$0.20/each")
  end

  feature "add", %{session: session, user: user} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> click(button("Add a package"))
    |> assert_text("Add a Package: Provide Details")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :new))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> assert_value(text_field("Image Turnaround Time"), "1")
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> click(css("div.ql-editor"))
    |> send_keys(["My greatest wedding package"])
    |> scroll_into_view(testid("modal-buttons"))
    |> click(css("label", text: "Portrait"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> fill_in(text_field("Package Price"), with: "$100")
    |> click(checkbox("Apply a discount or surcharge"))
    |> click(option("30%"))
    |> assert_text("-$30.00")
    |> click(option("Surcharge"))
    |> assert_text("+$30.00")
    |> scroll_into_view(testid("download"))
    |> click(checkbox("Set my own download price"))
    |> find(
      text_field("download_each_price"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> click(checkbox("Include download credits"))
    |> fill_in(text_field("download_count"), with: "2")
    |> assert_has(definition("Total Price", text: "$130.00"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_flash(:success, text: "The package has been successfully saved")
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :index))

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             description: "<p>My greatest wedding package</p>",
             base_price: %Money{amount: 10_000},
             download_count: 2,
             download_each_price: %Money{amount: 200},
             job_type: "portrait",
             package_template_id: nil
           } = user |> Package.templates_for_user() |> Repo.one!()
  end

  feature "edit", %{session: session, user: user} do
    template = insert(:package_template, user: user, print_credits: 20, buy_all: 20)

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> find(testid("package-template-card"))
    |> click(button("Manage"))
    |> click(button("Edit"))

    session
    |> assert_path(Routes.package_templates_path(PicselloWeb.Endpoint, :edit, template.id))
    |> within_modal(
      &(&1
        |> assert_text("Edit Package: Provide Details")
        |> assert_value(text_field("Title"), template.name)
        |> fill_in(text_field("Title"), with: "Wedding Super Deluxe")
        |> wait_for_enabled_submit_button()
        |> click(button("Next"))
        |> assert_text("Edit Package: Set Pricing")
        |> scroll_into_view(testid("download"))
        |> assert_has(radio_button("Do not charge for downloads", checked: true))
        |> click(radio_button("Charge for downloads", checked: false))
        |> assert_text("downloads are valued at #{Download.default_each_price()}")
        |> click(radio_button("Do not charge for downloads"))
        |> Kernel.tap(fn modal ->
          refute Regex.match?(~r/downloads are valued/, Element.text(modal))
        end)
        |> wait_for_enabled_submit_button()
        |> click(button("Save")))
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
          download_each_price: %Money{amount: 0}
      }
      |> Map.take([:id | form_fields])

    assert ^updated =
             user |> Package.templates_for_user() |> Repo.one!() |> Map.take([:id | form_fields])
  end

  feature "archive", %{session: session, user: user} do
    type = JobType.all() |> hd

    for name <- ~w(deluxe lame) do
      insert(:package_template,
        user: user,
        job_type: type,
        name: name,
        buy_all: 20,
        print_credits: 20
      )
    end

    lead = insert(:lead, user: user, type: type)

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> find(testid("package-template-card", text: "lame"))
    |> click(button("Manage"))
    |> click(button("Archive"))

    session
    |> click(button("Yes, archive"))
    |> find(testid("package-template-card", count: 1), &assert_text(&1, "deluxe"))
    |> assert_flash(:success, text: "The package has been archived")
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
    |> click(button("Add a package"))
    |> find(testid("template-card", count: 1), &assert_text(&1, "deluxe"))
  end
end
