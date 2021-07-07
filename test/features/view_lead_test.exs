defmodule Picsello.ViewLeadTest do
  use Picsello.FeatureCase, async: true

  import Picsello.JobFixtures

  setup :authenticated

  setup %{user: user} do
    [
      jobs:
        for(
          {client_name, job_type} <- [{"Rick Sanchez", "family"}, {"Morty Smith", "wedding"}],
          do:
            fixture(:job, %{
              user: user,
              type: job_type,
              client: %{name: client_name}
            })
        )
    ]
  end

  feature "user views job list", %{session: session} do
    session
    |> visit("/")
    |> click(link("View current leads"))
    |> assert_has(link("Rick Sanchez Family"))
    |> click(link("Morty Smith Wedding"))
    |> click(link("Leads"))
    |> click(link("Rick Sanchez Family"))
    |> assert_has(css("h1", text: "Rick Sanchez Family"))
  end
end
