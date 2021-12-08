defmodule Picsello.ClientVisitsPhotographerProfileTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Accounts.User

  feature "check it out", %{session: session} do
    user =
      insert(:user,
        organization: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos"
        },
        onboarding: %{
          color: "3376FF",
          job_types: ~w(portrait event),
          website: "http://photos.example.com"
        }
      )

    %User{organization: organization} = user

    session
    |> visit(Routes.profile_path(PicselloWeb.Endpoint, :index, organization.slug))
    |> assert_text("Mary Jane Photography")
    |> assert_text("What we offer:")
    |> assert_text("Portrait")
    |> assert_text("Event")
    |> assert_has(link("See our full portfolio"))
  end
end
