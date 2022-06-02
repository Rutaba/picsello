defmodule Picsello.EmailPresets.GalleryResolver do
  @moduledoc "resolves gallery mustache variables"

  defstruct [:gallery, :order, :helpers]
  alias Picsello.{Galleries.Gallery, Cart.Order}

  def new({%Gallery{} = gallery}, helpers),
    do: %__MODULE__{
      gallery: preload_gallery(gallery),
      helpers: helpers
    }

  def new({%Gallery{} = gallery, %Order{} = order}, helpers),
    do: %__MODULE__{
      gallery: preload_gallery(gallery),
      order: order,
      helpers: helpers
    }

  defp preload_gallery(gallery),
    do:
      Picsello.Repo.preload(gallery,
        job: [client: [organization: :user]]
      )

  defp gallery(%__MODULE__{gallery: gallery}), do: gallery

  defp order(%__MODULE__{order: order}), do: order

  defp job(%__MODULE__{gallery: gallery}),
    do: gallery |> Picsello.Repo.preload(:job) |> Map.get(:job)

  defp client(%__MODULE__{} = resolver),
    do: resolver |> job() |> Picsello.Repo.preload(:client) |> Map.get(:client)

  defp organization(%__MODULE__{} = resolver),
    do: resolver |> client() |> Picsello.Repo.preload(:organization) |> Map.get(:organization)

  defp photographer(%__MODULE__{} = resolver),
    do: resolver |> organization() |> Picsello.Repo.preload(:user) |> Map.get(:user)

  defp helpers(%__MODULE__{helpers: helpers}), do: helpers

  def vars,
    do: %{
      "client_first_name" => &(&1 |> client() |> Map.get(:name) |> String.split() |> hd),
      "photographer_first_name" =>
        &(&1 |> photographer() |> Map.get(:name) |> String.split() |> hd),
      "gallery_name" => &(&1 |> gallery() |> Map.get(:name)),
      "order_full_name" =>
        &with(
          %Order{delivery_info: %{name: name}} <- order(&1),
          do: name
        )
    }
end
