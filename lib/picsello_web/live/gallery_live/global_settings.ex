defmodule PicselloWeb.GelleryLive.GlobalSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{
    Repo,
    Galleries,
    Shoot,
    GlobalGallerySettings,
    Galleries.Workers.PhotoStorage
  }
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.GlobalGallerySettings
  alias Picsello.GlobalGallerySettings.Photo, as: GlobalPhoto
  alias Phoenix.PubSub
  alias Ecto.Changeset
  require Logger

  @upload_options [
    accept: ~w(.png image/png),
    max_entries: 100,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :photo_max_file_size)),
    auto_upload: true,
    external: &__MODULE__.presign_image/2,
    progress: &__MODULE__.handle_image_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(params, _session, %{assigns: %{current_user: current_user}} = socket) do
    global_gallery_settings =
      GlobalGallerySettings
      |> Repo.get_by(organization_id: current_user.organization.id)
    gallery =
      Galleries.list_all_galleries_by_organization_query(current_user.organization.id)
      |> Repo.all()
    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "preview_watermark:#{current_user.id}")
    end
    socket
    |> is_mobile(params)
    |> assign(gallery: gallery)
    |> assign(global_gallery_settings: global_gallery_settings)
    |> assign(is_expiration_date?: true)
    |> assign(watermark_option: false)
    |> assign_controls()
    |> assign_options()
    |> assign_title()
    |> assign(total_days: 0)
    |> assign(:upload_bucket, @bucket)
    |> assign(:case, :image)
    |> assign(:ready_to_save, false)
    |> assign(show_preview: false)
    |> assign(:watermarked_preview_path, nil)
    |> allow_upload(:image, @upload_options)
    |> ok()
  end

  @impl true
  def handle_event(
        "save",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    day = to_int(day)
    month = to_int(month)
    year = to_int(year)
    total_days = day + month * 30 + year * 365
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Go back",
      confirm_event: "set_expire",
      confirm_label: "Yes, set expiration date",
      icon: "warning-orange",
      subtitle:
        "All new galleries will expire #{if day > 0, do: "#{day} Day"} #{if month > 0, do: " #{month} Month "} #{if year > 0, do: " #{year} Year "} after their shoot date. When a gallery expires, a client will not be able to access it again unless you re-enable the individual gallery. ",
      title: "Set Galleries to Never Expire?",
      payload: %{total_days: total_days}
    })
    socket |> noreply()
  end

  def handle_event(
        "validate_days",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    day = to_int(day)
    month = to_int(month)
    year = to_int(year)
    total_days = day + month * 30 + year * 365
    socket |> assign(total_days: total_days, day: day, month: month, year: year) |> noreply()
  end

  def handle_event(
        "validate_days",
        _params,
        socket
      ) do
    socket
    |> noreply()
  end

  def handle_event(
        "save",
        %{},
        %{assigns: %{is_never_expires: true}} = socket
      ) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Go back",
      confirm_event: "never_expire",
      confirm_label: "Yes, set galleries to never expire",
      icon: "warning-orange",
      subtitle:
        "New galleries will default to never expire, but you can update a gallery's expiration date through its individual settings.",
      title: "Set Galleries to Never Expire?"
    })
    |> noreply()
  end

  @global_watermark_photo ~s(assets/static/images/watermark_preview.png)
  def handle_event(
        "preview_watermark",
        %{},
        %{
          assigns: %{current_user: current_user, changeset: changeset, show_preview: show_preview}
        } = socket
      ) do
    case show_preview do
      false ->
        file = File.read!(@global_watermark_photo)
        path = Application.fetch_env!(:picsello, :global_watermarked_path)
        {:ok, _object} = PhotoStorage.insert(path, file)
        ProcessingManager.update_watermark(%GlobalPhoto{
          id: UUID.uuid4(),
          user_id: current_user.id,
          original_url: path,
          text: Changeset.get_change(changeset, :watermark_text)
        })
        socket
        |> noreply()
      true ->
        socket
        |> assign(show_preview: false)
        |> noreply()
    end
  end

  def handle_event(
        "save_watermark",
        _params,
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            changeset: %{changes: changes},
            gallery: gallery,
            current_user: current_user
          }
        } = socket
      ) do
    changes = Map.put(changes, :organization_id, current_user.organization.id)
    socket =
      global_gallery_settings
      |> case do
        nil -> %GlobalGallerySettings{}
        settings -> settings
      end
      |> Ecto.Changeset.change(changes)
      |> Repo.insert_or_update()
      |> case do
        {:ok, ggs} ->
          attr =
            case ggs.watermark_type do
              "image" ->
                %{
                  name: ggs.watermark_name,
                  size: ggs.watermark_size,
                  type: "image"
                }
              "text" ->
                %{text: ggs.watermark_text, type: "text"}
            end
          gallery
          |> Enum.reject(&(&1.use_global == false))
          |> Enum.map(fn x ->
            {:ok, _gallery} = Galleries.save_gallery_watermark(x, attr)
          end)
          socket
          |> assign(global_gallery_settings: ggs)
          |> put_flash(:success, "Watermark Updated!")
          |> assign(:case, :image)
        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Update Watermark")
      end
    socket
    |> noreply()
  end

  @impl true
  def handle_event("delete", _, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Go back",
      confirm_event: "delete_watermarks",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      subtitle:
        "Are you sure you wish to permanently delete your custom watermark? You can always add another one later.",
      title: "Delete watermark?"
    })
    |> noreply()
  end

  def handle_event(
        "select_expiration",
        _,
        %{assigns: %{is_expiration_date?: is_expiration_date?}} = socket
      ) do
    socket
    |> assign(is_expiration_date?: !is_expiration_date?)
    |> assign_title()
    |> assign(watermark_option: false)
    |> assign_title()
    |> noreply()
  end

  def handle_event(
        "back_to_menu",
        _,
        socket
      ) do
    socket
    |> assign(is_expiration_date?: false)
    |> assign_title()
    |> assign(watermark_option: false)
    |> assign_title()
    |> noreply()
  end

  def handle_event(
        "select_watermark",
        _,
        %{assigns: %{watermark_option: watermark_option}} = socket
      ) do
    socket
    |> assign(watermark_option: !watermark_option)
    |> assign(is_expiration_date?: false)
    |> noreply()
  end

  @impl true
  def handle_event("image_case", _params, socket) do
    socket
    |> assign(:case, :image)
    |> assign_default_changeset()
    |> assign(:ready_to_save, false)
    |> noreply()
  end


  @impl true
  def handle_event("text_case", _params, socket) do
    socket
    |> assign(:case, :text)
    |> assign_default_changeset()
    |> assign(:ready_to_save, false)
    |> noreply()
  end
  @impl true
  def handle_event(
        "toggle-never-expires",
        _,
        %{assigns: %{is_never_expires: is_never_expires}} = socket
      ) do
    socket |> assign(is_never_expires: !is_never_expires) |> noreply()
  end

  @impl true
  def handle_event("validate_image_input", _params, socket) do
    socket
    |> handle_image_validation()
    |> noreply
  end

  def handle_event("validate_text_input", params, socket) do
    socket
    |> assign_text_watermark_change(params)
    |> noreply
  end

  defp assign_controls(%{assigns: %{global_gallery_settings: global_gallery_settings}} = socket)
       when not is_nil(global_gallery_settings) do
    if global_gallery_settings.expiration_days != 0 do
      socket |> assign(is_never_expires: false)
    else
      socket |> assign(is_never_expires: true)
    end
  end

  defp assign_controls(socket) do
    socket |> assign(is_never_expires: true)
  end

  defp assign_options(
         %{assigns: %{global_gallery_settings: %{expiration_days: expiration_days}}} = socket
       )
       when not is_nil(expiration_days) do
    year = trunc(expiration_days / 365)
    month = trunc((expiration_days - year * 365) / 30)
    day = trunc(expiration_days - year * 365 - month * 30)
    socket |> assign(day: day, month: month, year: year)
  end

  defp assign_options(socket) do
    socket |> assign(day: "day", month: "month", year: "year")
  end

  defp assign_title(
         %{
           assigns: %{
             is_expiration_date?: is_expiration_date?,
             watermark_option: watermark_option
           }
         } = socket
       ) do
    cond do
      is_expiration_date? -> socket |> assign(title: "Global Expiration Days")
      watermark_option -> socket |> assign(title: "Watermark")
      true -> socket |> assign(title: "Gallery Settings")
    end
  end

  defp get_shoots(job_id), do: Shoot.for_job(job_id) |> Repo.all()
  defp to_int(""), do: 0
  defp to_int(value), do: String.to_integer(value)

  @impl true
  def handle_info(
        {:preview_watermark, %{"watermarkedPreviewPath" => watermarked_preview_path}},
        socket
      ) do
    socket
    |> assign(show_preview: true)
    |> assign(:watermarked_preview_path, watermarked_preview_path)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "never_expire"},
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            gallery: gallery,
            current_user: current_user
          }
        } = socket
      ) do
    global_gallery_settings
    |> case do
      nil -> %GlobalGallerySettings{}
      settings -> settings
    end
    |> Ecto.Changeset.change(%{
      expiration_days: 0,
      organization_id: current_user.organization.id
    })
    |> Repo.insert_or_update()
    gallery
    |> Enum.reject(&(&1.use_global == false))
    |> Enum.each(&(&1 |> Ecto.Changeset.change(%{expired_at: nil}) |> Repo.update!()))
    socket
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> assign(day: 0, month: 0, year: 0)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_watermarks"},
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            gallery: gallery
          }
        } = socket
      ) do
    socket =
      global_gallery_settings
      |> Ecto.Changeset.change(%{
        watermark_type: nil,
        watermark_name: nil,
        watermark_text: nil,
        watermark_size: nil
      })
      |> Repo.update()
      |> case do
        {:ok, ggs} ->
          socket
          |> assign(global_gallery_settings: ggs)
          |> assign(:case, :image)
          |> assign_default_changeset()
          |> close_modal()
          |> put_flash(:success, "Settings updated")
        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Delete Watermark")
      end
    gallery
    |> Enum.reject(&(&1.use_global == false))
    |> Enum.map(fn x ->
      gal = Galleries.load_watermark_in_gallery(x)
      Galleries.delete_gallery_watermark(gal.watermark)
    end)
    socket
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "set_expire", %{total_days: total_days}},
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            gallery: gallery,
            current_user: current_user
          }
        } = socket
      ) do
    socket =
      global_gallery_settings
      |> case do
        nil -> %GlobalGallerySettings{}
        settings -> settings
      end
      |> Ecto.Changeset.change(%{
        expiration_days: total_days,
        organization_id: current_user.organization.id
      })
      |> Repo.insert_or_update()
      |> case do
        {:ok, ggs} ->
          socket
          |> assign(gloabal_gallery_settings: ggs)
          |> assign(is_never_expires: false)
        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Delete Watermark")
      end
    gallery
    |> Enum.reject(&(&1.use_global == false))
    |> Enum.map(fn x ->
      get_shoots(x.job_id)
      |> List.last()
      |> case do
        nil ->
          Ecto.Changeset.change(x, %{expired_at: nil})
          |> Repo.update!()
        shoot ->
          expired_at = Timex.shift(shoot.starts_at, days: total_days) |> Timex.to_datetime()
          Ecto.Changeset.change(x, %{expired_at: expired_at})
          |> Repo.update!()
      end
    end)
    socket
    |> close_modal()
    |> put_flash(:success, "Setting Updated")
    |> noreply()
  end

  def presign_image(
        image,
        %{
          assigns: %{current_user: current_user}
        } = socket
      ) do
    key = "galleries/#{current_user.organization_id}/watermark.png"
    sign_opts = [
      expires_in: 600,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => image.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [
        [
          "content-length-range",
          0,
          String.to_integer(Application.get_env(:picsello, :photo_max_file_size))
        ]
      ]
    ]
    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}
    {:ok, meta, socket}
  end

  def handle_image_progress(:image, %{done?: false}, socket), do: socket |> noreply()
  def handle_image_progress(:image, image, socket) do
    socket
    |> assign_image_watermark_change(image)
    |> noreply()
  end

  defp assign_image_watermark_change(
         %{assigns: %{global_gallery_settings: global_gallery_settings}} = socket,
         image
       ) do
    changeset =
      GlobalGallerySettings.global_gallery_image_watermark_change(global_gallery_settings, %{
        watermark_name: image.client_name,
        watermark_size: image.client_size
      })
    socket
    |> assign(:changeset, changeset)
    |> assign(:ready_to_save, changeset.valid?)
  end

  defp assign_default_changeset(
         %{assigns: %{global_gallery_settings: global_gallery_settings}} = socket
       ) do
    socket
    |> assign(
      :changeset,
      GlobalGallerySettings.global_gallery_watermark_change(global_gallery_settings)
    )
    |> assign(show_preview: false)
  end

  defp handle_image_validation(socket) do
    case socket.assigns.uploads.image.entries do
      %{valid?: false, ref: ref} -> cancel_upload(socket, :photo, ref)
      _ -> socket
    end
  end

  defp assign_text_watermark_change(
         %{assigns: %{global_gallery_settings: global_gallery_settings}} = socket,
         %{
           "global_gallery_settings" => %{"watermark_text" => watermark_text}
         }
       ) do
    changeset =
      GlobalGallerySettings.global_gallery_text_watermark_change(global_gallery_settings, %{
        watermark_text: watermark_text
      })
    socket
    |> assign(:changeset, changeset)
    |> assign(:ready_to_save, changeset.valid?)
  end

  defp preview_button_text(true), do: "Hide Preview"
  defp preview_button_text(false), do: "Show Preview"
  
  defp watermark_type(%{watermark_type: "image"}), do: :image
  defp watermark_type(%{watermark_type: "text"}), do: :text
  defp watermark_type(_), do: :undefined

  def card(assigns) do
    assigns = Enum.into(assigns, %{class: "", title_badge: nil})
    ~H"""
    <div class={"flex overflow-hidden border rounded-lg #{@class}"}>
      <div class="w-4 border-r bg-blue-planning-300" />
      <div class="flex flex-col justify-between w-full p-4">
        <div class="flex flex-col items-start sm:items-center sm:flex-row">
          <h1 class="mb-2 mr-4 text-xl font-bold sm:text-2xl text-blue-planning-300"><%= @title %></h1>
          <%= if @title_badge do %>
            <.badge color={:gray}><%= @title_badge %></.badge>
          <% end %>
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
