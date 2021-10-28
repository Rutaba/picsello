defmodule Picsello.UserManagesPackageTemplatesTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package, JobType}

  setup :onboarded
  setup :authenticated

  feature "navigate", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("You don’t have any packages")
  end

  feature "view list", %{session: session, user: user} do
    insert(:package_template, user: user, name: "Deluxe Template", download_count: 5)

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("Deluxe Template")
    |> assert_has(definition("Downloadable photos", text: "5"))
  end

  feature "add", %{session: session, user: user} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> click(button("Add a package"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> click(css("label", text: "Portrait"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> fill_in(text_field("Base Price"), with: "$100")
    |> fill_in(text_field("Add"), with: "$10")
    |> fill_in(text_field("Download"), with: "2")
    |> fill_in(text_field("each"), with: "$2")
    |> assert_has(definition("Total Price", text: "$114.00"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_flash(:success, text: "The package has been successfully saved")

    base_price = Money.new(10_000)
    gallery_credit = Money.new(1000)
    download_each_price = Money.new(200)

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             description: "My greatest wedding package",
             base_price: ^base_price,
             gallery_credit: ^gallery_credit,
             download_count: 2,
             download_each_price: ^download_each_price,
             job_type: "portrait",
             package_template_id: nil
           } = user |> Package.templates_for_user() |> Repo.one!()
  end

  feature "edit", %{session: session, user: user} do
    template = insert(:package_template, user: user)

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> find(testid("package-template-card"))
    |> click(button("Manage"))
    |> click(button("Edit"))

    session
    |> assert_value(text_field("Title"), template.name)
    |> fill_in(text_field("Title"), with: "Wedding Super Deluxe")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> find(testid("package-template-card"), &assert_text(&1, "Wedding Super Deluxe"))
    |> assert_flash(:success, text: "The package has been successfully saved")

    form_fields =
      ~w(base_price description job_type name gallery_credit download_count download_each_price shoot_count)a

    updated =
      %{template | name: "Wedding Super Deluxe"}
      |> Map.take([:id | form_fields])

    assert ^updated =
             user |> Package.templates_for_user() |> Repo.one!() |> Map.take([:id | form_fields])
  end

  feature "archive", %{session: session, user: user} do
    type = JobType.all() |> hd

    for name <- ~w(deluxe lame) do
      insert(:package_template, user: user, job_type: type, name: name)
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
    |> click(button("Add a package", count: 2, at: 1))
    |> find(testid("template-card", count: 1), &assert_text(&1, "deluxe"))
  end
end
