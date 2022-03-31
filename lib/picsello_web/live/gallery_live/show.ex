defmodule PicselloWeb.GalleryLive.Show do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.LiveHelpers

  alias Phoenix.PubSub
  alias Picsello.Galleries
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Galleries.PhotoProcessing.Waiter
  alias Picsello.Messages
  alias Picsello.Notifiers.ClientNotifier
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias PicselloWeb.GalleryLive.UploadComponent
  alias PicselloWeb.ConfirmationComponent
  alias PicselloWeb.GalleryLive.PhotoComponent

  @per_page 12
  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &__MODULE__.presign_cover_entry/2,
    progress: &__MODULE__.handle_cover_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:upload_bucket, @bucket)
      |> assign(:photo_updates, "false")
      |> assign(:cover_photo_processing, false)
      |> allow_upload(:cover_photo, @upload_options)
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    url = Routes.gallery_client_show_path(socket, :show, hash)

    socket
    |> assign(
      favorites_count: Galleries.gallery_favorites_count(gallery),
      favorites_filter: false,
      gallery: gallery,
      url: url,
      page: 0,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery),
      update_mode: "append"
    )
    |> assign_photos()
    |> then(fn
      %{
        assigns: %{
          live_action: :upload
        }
      } = socket ->
        send(self(), :open_modal)
        socket

      socket ->
        socket
    end)
    |> noreply()
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket.assigns.uploads.cover_photo
    |> case do
      %{valid?: false, ref: ref} -> {:noreply, cancel_upload(socket, :cover_photo, ref)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> noreply
  end

  @impl true
  def handle_event("open_upload_popup", _, socket) do
    send(self(), :open_modal)

    socket
    |> noreply()
  end

  @impl true
  def handle_event(
        "gallery_settings",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> push_redirect(to: Routes.gallery_settings_path(socket, :settings, gallery))
    |> noreply()
  end

  @impl true
  def handle_event(
        "load-more",
        _,
        %{
          assigns: %{
            page: page
          }
        } = socket
      ) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_favorites",
        _,
        %{
          assigns: %{
            favorites_filter: toggle_state
          }
        } = socket
      ) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "update_photo_position",
        %{"photo_id" => photo_id, "type" => type, "args" => args},
        %{
          assigns: %{
            gallery: %{
              id: gallery_id
            }
          }
        } = socket
      ) do
    Galleries.update_gallery_photo_position(
      gallery_id,
      photo_id
      |> String.to_integer(),
      type,
      args
    )

    PositionNormalizer.normalize(gallery_id)

    noreply(socket)
  end

  @impl true
  def handle_event(
        "delete_cover_photo_popup",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_cover_photo",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this photo?",
      subtitle: "Are you sure you wish to permanently delete this photo from #{gallery.name} ?"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_photo_popup",
        %{"id" => id},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_photo",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this photo?",
      subtitle: "Are you sure you wish to permanently delete this photo from #{gallery.name} ?",
      payload: %{
        photo_id: id
      }
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "client-link",
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    hash =
      gallery
      |> Galleries.set_gallery_hash()
      |> Map.get(:client_link_hash)

    gallery =
      gallery.id
      |> Galleries.get_gallery!()
      |> Picsello.Repo.preload(job: :client)

    link = Routes.gallery_client_show_url(socket, :show, hash)
    client_name = gallery.job.client.name

    subject = "#{gallery.name} photos"

    html = """
    <p>Hi #{client_name},</p>
    <p>Your gallery is ready to view! You can view the gallery here: <a href="#{link}">#{link}</a></p>
    <p>Your photos are password-protected, so you’ll also need to use this password to get in: <b>#{gallery.password}</b></p>
    <p>Happy viewing!</p>
    """

    text = """
    Hi #{client_name},

    Your gallery is ready to view! You can view the gallery here: #{link}

    Your photos are password-protected, so you’ll also need to use this password to get in: #{gallery.password}

    Happy viewing!
    """

    socket
    |> assign(:job, gallery.job)
    |> PicselloWeb.ClientMessageComponent.open(%{
      body_html: html,
      body_text: text,
      subject: subject,
      modal_title: "Share gallery"
    })
    |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset},
        %{
          assigns: %{
            job: job,
            gallery: gallery
          }
        } = socket
      ) do
    serialized_message =
      message_changeset
      |> :erlang.term_to_binary()
      |> Base.encode64()

    %{id: oban_job_id} =
      %{message: serialized_message, email: job.client.email, job_id: job.id}
      |> Picsello.Workers.ScheduleEmail.new(schedule_in: 900)
      |> Oban.insert!()

    Waiter.postpone(gallery.id, fn ->
      Oban.cancel_job(oban_job_id)

      {:ok, message} = Messages.add_message_to_job(message_changeset, job)
      ClientNotifier.deliver_email(message, job.client.email)
    end)

    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info({:photo_processed, _, photo}, socket) do
    photo_update =
      %{
        id: photo.id,
        url: display_photo(photo.watermarked_preview_url || photo.preview_url)
      }
      |> Jason.encode!()

    socket
    |> assign(:photo_updates, photo_update)
    |> noreply()
  end

  def handle_info({:cover_photo_processed, _, _}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.get_gallery!(gallery.id))
    |> assign(:cover_photo_processing, false)
    |> noreply()
  end

  def handle_info({:photo_click, _}, socket), do: noreply(socket)

  @impl true
  def handle_info(
        {:confirm_event, "delete_cover_photo"},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> assign(:gallery, Galleries.delete_gallery_cover_photo(gallery))
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_photo", %{photo_id: id}},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    Galleries.get_photo(id)
    |> Galleries.delete_photo()

    {:ok, gallery} = Galleries.update_gallery(gallery, %{total_count: gallery.total_count - 1})

    send_update(PhotoComponent, id: String.to_integer(id), is_removed: true)

    socket
    |> assign(:gallery, gallery)
    |> close_modal()
    |> push_event("remove_item", %{"id" => id})
    |> noreply()
  end

  def handle_info(
        :open_modal,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> open_modal(UploadComponent, %{gallery: gallery})
    |> noreply()
  end

  def handle_info(:close_upload_popup, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:photo_upload_completed, _count},
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    Galleries.update_gallery_photo_count(gallery.id)

    Galleries.normalize_gallery_photo_positions(gallery.id)

    socket
    |> push_redirect(to: Routes.gallery_show_path(socket, :show, gallery.id))
    |> noreply()
  end

  def handle_cover_progress(:cover_photo, entry, %{assigns: %{gallery: gallery}} = socket) do
    if entry.done? do
      CoverPhoto.original_path(gallery.id, entry.uuid)
      |> ProcessingManager.process_cover_photo()

      socket
      |> assign(:cover_photo_processing, true)
      |> noreply()
    else
      socket
      |> noreply
    end
  end

  def presign_cover_entry(entry, %{assigns: %{gallery: gallery}} = socket) do
    key = CoverPhoto.original_path(gallery.id, entry.uuid)

    sign_opts = [
      expires_in: 600,
      bucket: socket.assigns.upload_bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]

    params = PhotoStorage.params_for_upload(sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}

    {:ok, meta, socket}
  end

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{
               id: id
             },
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(
      :photos,
      photos
      |> Enum.take(per_page)
    )
    |> assign(
      :has_more_photos,
      photos
      |> length > per_page
    )
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
  defp page_title(:upload), do: "New Gallery"

  def product_preview_url(%{
        preview_photo: %{
          preview_url: url
        }
      }),
      do: url

  def product_preview_url(_), do: nil
end
