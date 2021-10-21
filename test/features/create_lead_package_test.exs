defmodule Picsello.CreateLeadPackageTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package}

  setup :onboarded
  setup :authenticated

  feature "user without package templates creates a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Add a package"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
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
             download_each_price: ^download_each_price
           } = lead |> Repo.reload() |> Repo.preload(:package) |> Map.get(:package)
  end

  feature "user with package templates chooses one", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    insert(:package_template, user: user, job_type: "wedding", name: "best wedding")
    insert(:package_template, user: user, job_type: "other")

    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Add a package"))
    |> find(testid("template-card", count: 1))
    |> assert_text("best wedding")
  end

  feature "user sees validation errors when creating a package", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Add a package"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: " ")
    |> fill_in(text_field("Description"), with: " ")
    |> assert_has(css("label", text: "Title can't be blank"))
    |> assert_has(css("label", text: "Description can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Base Price"), with: " ")
    |> fill_in(text_field("Add"), with: " ")
    |> fill_in(text_field("Download"), with: " ")
    |> fill_in(text_field("each"), with: " ")
    |> assert_has(definition("Total Price", text: "$0.00"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user navigates back and forth on steps", %{session: session, user: user} do
    lead = insert(:lead, %{user: user, client: %{name: "Elizabeth Taylor"}, type: "wedding"})

    session
    |> visit("/leads/#{lead.id}")
    |> click(button("Add a package"))
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Description"), with: "My greatest wedding package")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_has(css("button:disabled[type='submit']"))
    |> fill_in(text_field("Base Price"), with: "$100")
    |> click(testid("step-number", text: "Step 2"))
    |> assert_has(testid("step-number", text: "Step 1"))
    |> assert_value(text_field("Title"), "Wedding Deluxe")
    |> click(button("Next"))
    |> assert_has(testid("step-number", text: "Step 2"))
    |> assert_value(text_field("Base Price"), "$100.00")
    |> assert_has(css("button:disabled[type='submit']"))
  end
end
