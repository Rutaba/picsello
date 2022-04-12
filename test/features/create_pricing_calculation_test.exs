defmodule Picsello.CreatePricingCalculationTest do
  use Picsello.FeatureCase, async: true

  setup :tax_schedule
  setup :business_costs

  setup do
    insert(:cost_of_living_adjustment)

    %{
      user:
        insert(:user,
          organization: %{
            name: "Mary Jane Photography",
            slug: "mary-jane-photos",
            profile: %{
              job_types: ~w(portrait event),
              website: "photos.example.com"
            }
          }
        )
        |> onboard!
    }
  end

  setup :authenticated

  feature "user creates pricing calculation", %{session: session} do
    session
    |> click(link("calculate your pricing"))
    |> click(button("Get started"))
    |> assert_path("/pricing/calculator")
    |> click(css("label", text: "Wedding"))
    |> assert_has(css("label.border-blue-planning-300", count: 3))
    |> assert_has(css("select#calculator-step-2_schedule", text: "Part-time"))
    |> fill_in(css("#calculator-step-2_zipcode"), with: "98661")
    |> assert_has(css("#calculator-step-2_min_years_experience", value: "1"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("Financial & time goals")
    |> assert_text("15.3%")
    |> fill_in(css("#calculator-step-3_average_time_per_week"), with: "26")
    |> click(css("label.capitalize:first-child"))
    |> click(css("label.capitalize:nth-child(3)"))
    |> assert_has(css("label.capitalize.border-blue-planning-300", count: 2))
    |> find(
      text_field("calculator-step-3_desired_salary"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$36000"))
    )
    |> assert_text("24%")
    |> assert_text("$28,759.04")
    |> assert_text("$24,358.91")
    |> click(button("Next"))
    |> assert_text("Business costs")
    |> assert_text("Equipment")
    |> assert_text("$24,358.91")
    |> assert_text("Equipment")
    |> assert_text("$6,500")
    |> assert_text("$30,858.91")
    |> click(button("Edit costs"))
    |> assert_text("Edit Equipment costs")
  end

  feature "user see validation error when calculating price", %{session: session} do
    session
    |> click(link("calculate your pricing"))
    |> click(button("Get started"))
    |> assert_path("/pricing/calculator")
    |> click(css("label", text: "Wedding"))
    |> assert_has(css("label.border-blue-planning-300", count: 3))
    |> assert_has(css("select#calculator-step-2_schedule", text: "Part-time"))
    |> assert_has(css("#calculator-step-2_min_years_experience", value: "1"))
    |> assert_disabled(css("button", text: "Next"))
  end

  feature "user exits calculator from home screen", %{session: session} do
    session
    |> click(link("calculate your pricing"))
    |> click(link("Exit calculator"))
    |> assert_path("/home")
  end

  feature "user clicks go back from home screen", %{session: session} do
    session
    |> click(link("calculate your pricing"))
    |> click(link("Go back"))
    |> assert_path("/home")
  end

  feature "user exits calculator from a step screen", %{session: session} do
    session
    |> click(link("calculate your pricing"))
    |> click(button("Get started"))
    |> click(css(".circleBtn a"))
    |> assert_path("/home")
  end
end
