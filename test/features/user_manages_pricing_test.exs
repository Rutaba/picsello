defmodule Picsello.UserManagesPricingTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo

  setup :onboarded
  setup :authenticated

  setup do
    read_fixture =
      &("test/support/fixtures/whcc/api/v1/#{&1}.json" |> File.read!() |> Jason.decode!())

    Picsello.MockWHCCClient
    |> Mox.stub(:products, fn ->
      for(product <- read_fixture.("products"), do: Picsello.WHCC.Product.from_map(product))
    end)
    |> Mox.stub(:product_details, fn %{id: id} = product ->
      Picsello.WHCC.Product.add_details(product, read_fixture.("products/#{id}"))
    end)
    |> Mox.stub(:designs, fn ->
      for(design <- read_fixture.("designs"), do: Picsello.WHCC.Design.from_map(design))
    end)
    |> Mox.stub(:design_details, fn %{id: id} = design ->
      Picsello.WHCC.Design.add_details(design, read_fixture.("designs/#{id}"))
    end)

    Picsello.WHCC.sync()

    Repo.update_all(Picsello.Category, set: [hidden: false])

    :ok
  end

  def expand_variation_row(session, variation_name, f) do
    session
    |> find(
      testid("product", at: 0, count: 2),
      fn product ->
        product
        |> find(css(".contents", text: variation_name), fn variation ->
          variation
          |> click(button("Expand"))
          |> f.()
          |> click(button("Expand"))
        end)
      end
    )
  end

  def find_attribute_row(session, attribute_name, f),
    do: find(session, css(".contents", text: attribute_name), f)

  feature "modify pricing", %{session: session} do
    lustre_attribute = "Surface Lustre"

    session
    |> click(link("Settings"))
    |> click(link("Gallery Store Pricing"))
    |> click(link("Loose Prints"))
    |> assert_text("Adjust Pricing: Loose Prints")
    |> click(button("Expand All", at: 0, count: 3))
    |> expand_variation_row("4×4", fn variation ->
      variation
      |> find_attribute_row(lustre_attribute, fn row ->
        row
        |> find(testid("profit"), &assert_text(&1, "$0.78"))
        |> assert_value(testid("markup"), "100%")
        |> fill_in(testid("markup"), with: "200%")
        |> find(testid("profit"), &assert_text(&1, "$1.56"))
      end)
    end)
    |> click(link("Gallery Store Pricing"))
    |> click(link("Loose Prints"))
    |> click(button("Expand All", at: 0, count: 3))
    |> expand_variation_row("4×4", fn variation ->
      variation
      |> find_attribute_row(lustre_attribute, fn attribute ->
        attribute
        |> assert_value(testid("markup"), "200%")
      end)
    end)
    |> expand_variation_row("4×4", fn variation ->
      variation
      |> find_attribute_row(lustre_attribute, fn attribute ->
        attribute
        |> fill_in(testid("markup"), with: "")
        |> assert_has(css(".text-input-invalid"))
      end)
      |> find_attribute_row("Surface Glossy", fn attribute ->
        attribute
        |> fill_in(testid("markup"), with: "2%")
        |> assert_has(css("input:not(.text-input-invalid)"))
      end)
      |> find_attribute_row(lustre_attribute, fn attribute ->
        # error ignored
        attribute
        |> assert_value(css("input:not(.text-input-invalid)"), "200%")
      end)
    end)
  end
end
