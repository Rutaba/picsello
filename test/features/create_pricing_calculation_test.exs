defmodule Picsello.CreatePricingCalculationTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  setup :tax_schedule
  setup :business_costs

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    insert(:cost_of_living_adjustment)

    user = %{
      user:
        insert(:user,
          organization: %{
            name: "Mary Jane Photography",
            slug: "mary-jane-photos",
            profile: %{
              job_types: ~w(portrait event)
            }
          }
        )
        |> onboard!
    }

    insert(:brand_link, user)

    user
  end

  setup :authenticated

  feature "user creates pricing calculation", %{
    session: session,
    user: %{name: user_name, email: user_email}
  } do
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
    |> assert_text("$36,000.00")
    |> assert_text("Equipment")
    |> assert_text("$6,500")
    |> assert_text("$42,500.00")
    |> click(button("Edit costs"))
    |> assert_text("Edit Equipment costs")
    |> assert_text("Camera")
    |> fill_in(css("#calculator-step-6_business_costs_0_line_items_0_yearly_cost"),
      with: "$7000"
    )
    |> assert_text("$583.33")
    |> assert_text("$625.00")
    |> assert_text("$7,500.00")
    |> click(button("Save & go back"))
    |> assert_text("$7,500")
    |> click(button("Next"))
    |> assert_text("Results")
    |> click(button("Email results"))
    |> assert_text("Your results have been saved")
    |> click(button("Go to my dashboard"))

    assert_receive {:delivered_email,
                    %{
                      to: [{^user_name, ^user_email}],
                      private: %{
                        send_grid_template: %{
                          dynamic_template_data: %{
                            "gross_revenue" => "$31,858.91",
                            "pricing_suggestions" => [],
                            "projected_costs" => "$7,500.00",
                            "take_home" => "$24,358.91"
                          }
                        }
                      }
                    }}
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

  feature "user visits from packages", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> click(link("use here"))
    |> assert_path("/pricing/calculator")
  end
end
