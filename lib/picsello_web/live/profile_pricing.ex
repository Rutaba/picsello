defmodule PicselloWeb.Live.ProfilePricing do
  @moduledoc "photographers public profile pricing"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Profiles, Packages}

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    """
  end
end
