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

  defp strftime(%__MODULE__{helpers: helpers} = resolver, date, format) do
    resolver |> photographer() |> Map.get(:time_zone) |> helpers.strftime(date, format)
  end

  defp helpers(%__MODULE__{helpers: helpers}), do: helpers

  def vars,
    do: %{
      "client_first_name" => &(&1 |> client() |> Map.get(:name) |> String.split() |> hd),
      "password" => &(&1 |> gallery() |> Map.get(:password)),
      "gallery_link" => fn resolver ->
        helpers(resolver).gallery_url(gallery(resolver).client_link_hash)
      end,
      "photography_company_s_name" => &organization(&1).name,
      "photographer_first_name" =>
        &(&1 |> photographer() |> Map.get(:name) |> String.split() |> hd),
      "gallery_name" => &(&1 |> gallery() |> Map.get(:name)),
      "gallery_expiration_date" =>
        &with(
          %DateTime{} = expired_at <- &1 |> gallery() |> Map.get(:expired_at),
          do: strftime(&1, expired_at, "%B %-d, %Y")
        ),
      "order_first_name" =>
        &with(
          %Order{delivery_info: %{name: "" <> name}} <- order(&1),
          do: name |> String.split() |> hd
        ),
      "order_full_name" =>
        &with(
          %Order{delivery_info: %{name: "" <> name}} <- order(&1),
          do: name
        )
    }
end
