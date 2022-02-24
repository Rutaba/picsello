defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package}

  setup :onboarded
  setup :authenticated

  @add_package_button testid("add-package-from-shoot")

  def fill_in_package_form(session) do
    session
    |> assert_text("Add a Package: Provide Details")
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Add a Package: Set Pricing")
    |> find(button("Save"), &assert(Element.attr(&1, :disabled)))
    |> fill_in(text_field("Base Price"), with: "$100")
    |> click(checkbox("Set my own download price"))
    |> find(
      text_field("download_each_price"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> click(checkbox("Include download credits"))
    |> fill_in(text_field("download_count"), with: "2")
    |> assert_has(definition("Total Price", text: "$100.00"))
  end

  feature "user without package templates creates a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    base_price = Money.new(10_000)
    download_each_price = Money.new(200)

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             description: "My greatest wedding package",
             base_price: ^base_price,
             download_count: 2,
             download_each_price: ^download_each_price
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user with package templates sees them", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    insert(:package_template, user: user, job_type: "wedding", name: "best wedding")
    insert(:package_template, user: user, job_type: "wedding", name: "lame wedding")

    insert(:package_template, user: user, job_type: "other")

    selected_card = css("[data-testid='template-card'] > .border-blue-planning-300")

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

    insert(:package_template, user: user, job_type: "wedding", name: "best wedding")

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> click(button("New Package"))
    |> fill_in_package_form()
    |> click(link("back"))
    |> click(link("back"))
    |> click(button("New Package"))
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
  end

  feature "user with package templates uses one as-is", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    base_price = Money.new(10_000)
    download_each_price = Money.new(200)

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding",
        shoot_count: 1,
        description: "desc",
        base_price: base_price,
        download_count: 1,
        download_each_price: download_each_price
      )

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
             download_count: 1,
             download_each_price: ^download_each_price,
             package_template_id: ^template_id
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user customizes package template", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    base_price = Money.new(10_000)
    download_each_price = Money.new(200)

    template =
      insert(:package_template,
        user: user,
        job_type: "wedding",
        name: "best wedding",
        shoot_count: 2,
        description: "desc",
        base_price: base_price,
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
    |> assert_value(text_field("Description"), "desc")
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_value(text_field("Base Price"), "$100.00")
    |> assert_value(text_field("download_count"), "1")
    |> assert_value(text_field("download_each_price"), "$2.00")
    |> fill_in(text_field("Base Price"), with: "200")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    template_id = template.id
    base_price = Money.new(20_000)

    assert %Package{
             name: "Wedding Deluxe",
             job_type: nil,
             shoot_count: 2,
             description: "desc",
             base_price: ^base_price,
             download_count: 1,
             download_each_price: ^download_each_price,
             package_template_id: ^template_id
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(@add_package_button)
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: " ")
    |> assert_has(css("label", text: "Title can't be blank"))
    |> fill_in(text_field("Description"), with: " ")
    |> assert_has(css("label", text: "Description can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_disabled_submit(text: "Save")
    |> fill_in(text_field("Base Price"), with: " ")
    |> click(checkbox("Include download credits"))
    |> fill_in(text_field("download_count"), with: " ")
    |> click(checkbox("Set my own download price"))
    |> fill_in(text_field("download_each_price"), with: " ")
    |> assert_has(definition("Total Price", text: "$0.00"))
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
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_disabled_submit()
    |> fill_in(text_field("Base Price"), with: "$100")
    |> click(testid("step-number", text: "Step 2"))
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_value(text_field("Title"), "Wedding Deluxe")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_value(text_field("Base Price"), "$100.00")
  end
end
