defmodule PicselloWeb.GalleryLive.Photos.PreviewComponent do
  @moduledoc "no doc"
  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers

  alias Phoenix.PubSub
  alias Picsello.Repo
  alias Picsello.{Galleries, GalleryProducts}

  @impl true
  def update(assigns,socket) do

    socket
    |> assign(assigns)
    |> ok()
  end

end
