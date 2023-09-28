defmodule Picsello.EmailPresets.GalleryResolver do
  @moduledoc "resolves gallery mustache variables"

  defstruct [:gallery, :order, :album, :helpers]
  alias Picsello.{Galleries.Gallery, Galleries.Album, Cart.Order, Pack}

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

  def new({%Gallery{} = gallery, %Album{} = album}, helpers),
    do: %__MODULE__{
      gallery: preload_gallery(gallery),
      album: album,
      helpers: helpers
    }

  defp preload_gallery(gallery),
    do:
      Picsello.Repo.preload(gallery,
        job: [client: [organization: :user]]
      )

  defp gallery(%__MODULE__{gallery: gallery}), do: gallery

  defp order(%__MODULE__{order: order}), do: order

  defp album(%__MODULE__{album: album}), do: album

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

  defp download_photos_link(%__MODULE__{gallery: gallery}) do
    case Pack.url(gallery) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp show_red_section(%__MODULE__{}), do: false

  defp helpers(%__MODULE__{helpers: helpers}), do: helpers

  def vars,
    do: %{
      "client_first_name" => &(&1 |> client() |> Map.get(:name) |> String.split() |> hd),
      "password" => &(&1 |> gallery() |> Map.get(:password)),
      "gallery_link" => fn resolver ->
        """
        <a style="border:1px solid #1F1C1E;display:inline-block;background:white;color:#1F1C1E;font-family:Montserrat, sans-serif;font-size:18px;font-weight:normal;line-height:120%;margin:0;text-decoration:none;text-transform:none;padding:10px 15px;mso-padding-alt:0px;border-radius:0px;"
           target="_blank"
           href="#{helpers(resolver).gallery_url(gallery(resolver).client_link_hash)}"> Gallery Link
        </a>
        """
      end,
      "photography_company_s_name" => &organization(&1).name,
      "photographer_first_name" => &(&1 |> photographer() |> Picsello.Accounts.User.first_name()),
      "gallery_name" => &(&1 |> gallery() |> Map.get(:name)),
      "download_photos" =>
        &with(
          link <- download_photos_link(&1),
          do: """
          <a style="border:1px solid #1F1C1E;display:inline-block;background:white;color:#1F1C1E;font-family:Montserrat, sans-serif;font-size:18px;font-weight:normal;line-height:120%;margin:0;text-decoration:none;text-transform:none;padding:10px 15px;mso-padding-alt:0px;border-radius:0px;"
             target="_blank"
             href="#{link}"> Download Photos Link
          </a>
          """
        ),
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
        ),
      "album_link" =>
        &with(
          %Album{client_link_hash: "" <> client_link_hash} <- album(&1),
          do: """
          <a style="border:1px solid #1F1C1E;display:inline-block;background:white;color:#1F1C1E;font-family:Montserrat, sans-serif;font-size:18px;font-weight:normal;line-height:120%;margin:0;text-decoration:none;text-transform:none;padding:10px 15px;mso-padding-alt:0px;border-radius:0px;"
             target="_blank"
             href="#{helpers(&1).album_url(client_link_hash)}"> Download Photos Link
          </a>
          """
        ),
      "album_password" => &(&1 |> gallery() |> Map.get(:password)),
      "first_red_section" => &show_red_section/1,
      "second_red_section" => &show_red_section/1
    }
end
