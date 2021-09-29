defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view
  alias Picsello.Accounts.User

  def meta_tags do
    %{
      "google-site-verification" => Application.get_env(:picsello, :google_site_verification),
      "google-maps-api-key" => System.get_env("GOOGLE_MAPS_API_KEY")
    }
    |> Enum.filter(&elem(&1, 1))
  end
end
