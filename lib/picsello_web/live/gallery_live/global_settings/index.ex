defmodule PicselloWeb.GalleryLive.GlobalSettings.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{
    Repo,
    Galleries,
    Shoot
  }

  alias Galleries.{PhotoProcessing.ProcessingManager, Workers.PhotoStorage}
  alias PicselloWeb.GalleryLive.GlobalSettings.{ProductComponent, PrintProductComponent}
  alias Phoenix.PubSub
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Ecto.Changeset
  require Logger

  @upload_options [
    accept: ~w(.png image/png),
    max_entries: 1,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :photo_max_file_size)),
    auto_upload: true,
    external: &__MODULE__.presign_image/2,
    progress: &__MODULE__.handle_image_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  @global_watermark_photo ~s(assets/static/images/watermark_preview.png)

  @impl true
  def mount(params, _session, %{assigns: %{current_user: current_user}} = socket) do
    global_gallery_settings =
      GSGallery
      |> Repo.get_by(organization_id: current_user.organization.id)

    galleries =
      Galleries.list_all_galleries_by_organization_query(current_user.organization.id)
      |> Repo.all()

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "preview_watermark:#{current_user.id}")
      PubSub.subscribe(Picsello.PubSub, "save_watermark:#{current_user.id}")
    end

    socket
    |> is_mobile(params)
    |> assign(galleries: galleries)
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
    |> assign(:product_section?, nil)
    |> assign(:print_price_section?, nil)
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
    |> noreply()
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

        ProcessingManager.update_watermark(%GSGallery.Photo{
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
            galleries: galleries,
            current_user: %{organization_id: organization_id} = current_user,
            case: case_coming
          }
        } = socket
      ) do
    case case_coming do
      :image ->
        file = File.read!(@global_watermark_photo)
        path = Application.fetch_env!(:picsello, :global_watermarked_path)

        {:ok, _object} = PhotoStorage.insert(path, file)

        ProcessingManager.update_watermark(
          %GSGallery.Photo{
            id: UUID.uuid4(),
            user_id: current_user.id,
            original_url: path,
            text: "nil"
          },
          changes.organization_id
        )

      :text ->
        nil
    end

    global_gallery_settings ||
      %GSGallery{}
      |> Ecto.Changeset.change(Map.put(changes, :organization_id, organization_id))
      |> Repo.insert_or_update()
      |> case do
        {:ok, global_settings} ->
          galleries
          |> Enum.reject(&(!&1.use_global))
          |> Enum.each(fn gallery ->
            {:ok, _gallery} = Galleries.save_gallery_watermark(gallery, attrs(global_settings))
          end)

          socket
          |> assign(global_gallery_settings: global_settings)
          |> put_flash(:success, "Watermark Updated!")
          |> assign(:case, :image)

        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Update Watermark")
      end
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
        socket
      ) do
    socket
    |> assign(is_expiration_date?: true)
    |> assign(watermark_option: false)
    |> assign(product_section?: false)
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
    |> assign(watermark_option: false)
    |> assign(product_section?: false)
    |> assign_title()
    |> noreply()
  end

  def handle_event(
        "select_watermark",
        _,
        socket
      ) do
    socket
    |> assign(watermark_option: true)
    |> assign(is_expiration_date?: false)
    |> assign(product_section?: false)
    |> assign_title()
    |> noreply()
  end

  def handle_event(
        "select_product",
        _,
        socket
      ) do
    socket
    |> assign(watermark_option: false)
    |> assign(is_expiration_date?: false)
    |> assign(print_price_section?: false)
    |> assign(product_section?: true)
    |> assign_title()
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

  @impl true
  def handle_event("close", %{"ref" => ref}, socket) do
    socket
    |> assign_default_changeset()
    |> cancel_upload(:image, ref)
    |> noreply()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> assign_default_changeset()
    |> noreply()
  end

  @impl true
  def handle_event(
        "back_to_products",
        _,
        socket
      ) do
    send(self(), {:back_to_products})

    socket |> noreply()
  end

  defp assign_controls(%{assigns: %{global_gallery_settings: global_gallery_settings}} = socket)
       when not is_nil(global_gallery_settings) do
    socket |> assign(is_never_expires: global_gallery_settings.expiration_days == 0)
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

  defp assign_title(%{assigns: %{is_expiration_date?: true}} = socket),
    do: socket |> assign(:title, "Global Expiration Days")

  defp assign_title(%{assigns: %{watermark_option?: true}} = socket),
    do: socket |> assign(:title, "Watermark")

  defp assign_title(%{assigns: %{print_price_section?: true}} = socket),
    do: socket |> assign(:title, "Print Pricing")

  defp assign_title(%{assigns: %{product_section?: true}} = socket),
    do: socket |> assign(:title, "Product Settings & Prices")

  defp assign_title(socket), do: socket |> assign(:title, "Gallery Settings")

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
        {:save_watermark, %{"watermarkedPreviewPath" => watermarked_preview_path}},
        socket
      ) do
    {:ok, global_settings} =
      socket.assigns.global_gallery_settings
      |> case do
        nil -> %GSGallery{}
        settings -> settings
      end
      |> Ecto.Changeset.change(global_watermark_path: watermarked_preview_path)
      |> Repo.insert_or_update()

    socket
    |> assign(global_gallery_settings: global_settings)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "never_expire"},
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            galleries: galleries,
            current_user: current_user
          }
        } = socket
      ) do
    global_gallery_settings ||
      %GSGallery{}
      |> Ecto.Changeset.change(%{
        expiration_days: 0,
        organization_id: current_user.organization.id
      })
      |> Repo.insert_or_update()

    galleries
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
            galleries: galleries
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
        {:ok, global_settings} ->
          socket
          |> assign(global_gallery_settings: global_settings)
          |> assign(:case, :image)
          |> assign_default_changeset()
          |> close_modal()
          |> put_flash(:success, "Settings updated")

        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Delete Watermark")
      end

    _gallery =
      galleries
      |> Enum.reject(&(&1.use_global == false))
      |> Enum.map(fn x ->
        gallery = Galleries.load_watermark_in_gallery(x)
        Galleries.delete_gallery_watermark(gallery.watermark)
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
            galleries: galleries,
            current_user: current_user
          }
        } = socket
      ) do
    socket =
      global_gallery_settings
      |> case do
        nil -> %GSGallery{}
        settings -> settings
      end
      |> Ecto.Changeset.change(%{
        expiration_days: total_days,
        organization_id: current_user.organization.id
      })
      |> Repo.insert_or_update()
      |> case do
        {:ok, global_settings} ->
          socket
          |> assign(gloabal_gallery_settings: global_settings)
          |> assign(is_never_expires: false)

        {:error, _} ->
          socket
          |> put_flash(:error, "Failed to Delete Watermark")
      end

    _gallery =
      galleries
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

  def handle_info({:select_print_prices, product}, socket) do
    socket
    |> assign(print_price_section?: true)
    |> assign_title()
    |> assign(:product, product)
    |> noreply()
  end

  def handle_info({:back_to_products}, socket) do
    socket
    |> assign(print_price_section?: false)
    |> assign(product_section?: true)
    |> assign_title()
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

  defp attrs(%{watermark_type: watermark_type} = global_settings) do
    case watermark_type do
      "image" ->
        %{
          name: global_settings.watermark_name,
          size: global_settings.watermark_size,
          type: "image"
        }

      "text" ->
        %{text: global_settings.watermark_text, type: "text"}
    end
  end

  defp assign_image_watermark_change(
         %{assigns: %{global_gallery_settings: global_gallery_settings}} = socket,
         image
       ) do
    changeset =
      GSGallery.global_gallery_image_watermark_change(global_gallery_settings, %{
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
      GSGallery.global_gallery_watermark_change(global_gallery_settings)
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
      GSGallery.global_gallery_text_watermark_change(global_gallery_settings, %{
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

  defp expiration_section(assigns) do
    ~H"""
      <h1 class={classes("text-2xl font-bold mt-6 md:block", %{"hidden" => @is_expiration_date?})}>Global Expiration Date</h1>
      <.card color="blue-planning-300" icon="three-people" title="Expiration Date" badge={0} class="cursor-pointer mt-8" >
          <p class="my-2">
            Add a global expiration date that will be the default setting across all your new galleries.
            This will not affect your pre-existing galleries. If your job doesn’t have a shoot date, the gallery
            for that job will default to <i>“Never Expires”</i>. New galleries will expire:
          </p>
          <.form let={f} for={:global_expiration_days} phx-submit="save" phx-change="validate_days">
            <div class="items-center">
              <%= for {name, max, number, title} <- [{:day, 30, @day, "days,"}, {:month, 11, @month, "months,"}, {:year, 5, @year, "years after their shoot date."}] do %>
                <.date_input f={f} name={name} max={max} number={number} is_never_expires={@is_never_expires} />
                <%= title %>
              <% end %>
            </div>
            <div data-testid="toggle_expiry" class="flex flex-col md:flex-row md:items-center justify-between w-full mt-5">
                <div class="flex" phx-click="toggle-never-expires" id="updateGalleryNeverExpire">
                  <input id="neverExpire" type="checkbox" class="w-6 h-6 mr-3 checkbox-exp cursor-pointer" checked={@is_never_expires}>
                  <label class="cursor-pointer"> New galleries will never expire</label>
                </div>
                <button class="btn-primary w-full mt-5 md:mt-0 md:w-32" id="saveGalleryExpiration"
                  phx-disable-with="Saving..." type="submit" phx-submit="save"
                  disabled= {@total_days == 0 && @is_never_expires == false} >
                  Save
                </button>
            </div>
          </.form>
      </.card>
    """
  end

  defp date_input(%{f: f, name: name, max: max, number: number} = assigns) do
    ~H"""
    <%= input f, name, type: :number_input, min: 0, max: max , value: if(number > 0, do: number),
      placeholder: "1",
      class: "border-blue-planning-300 mx-2 md:mx-3 w-20 cursor-pointer 'text-gray-400 cursor-default border-blue-planning-200",
      disabled: @is_never_expires %>
    """
  end

  defp watermark_section(%{uploads: uploads} = assigns) do
    entry = Enum.at(uploads.image.entries, 0)

    ~H"""
    <h1 class={classes("text-2xl font-bold mt-6 md:block", %{"hidden" => @watermark_option})}>Watermark</h1>
    <.card color="blue-planning-300" icon="three-people" title="Custom Watermark" badge={0} class="cursor-pointer mt-8" >
      <%= if @case == :image and watermark_type(@global_gallery_settings) == :image do  %>

        <img src={"#{@global_gallery_settings.global_watermark_path && PhotoStorage.path_to_url(@global_gallery_settings.global_watermark_path)}"} />
        <div class="flex justify-between mb-8 mt-11 font-sans">
            <p><%= @global_gallery_settings.watermark_name %></p>

            <div class="flex">
              <p><%= filesize(@global_gallery_settings.watermark_size) %></p>
              <.remove_button />
            </div>
        </div>
      <% end %>

      <%= if watermark_type(@global_gallery_settings) == :text do  %>
        <div class="flex justify-between mb-8 mt-11 font-sans">
            <p><%= @global_gallery_settings.watermark_text %></p>
            <div class="flex items-center">
              <.icon name="typography-symbol" class="w-3 h-3.5 ml-1 fill-current"/>
              <.remove_button />
            </div>
        </div>
      <% end %>

      <%= if @case == :image and watermark_type(@global_gallery_settings) == :text do  %>
        <div class="flex items-start justify-between px-6 py-3 errorWatermarkMessage sm:items-center mb-7" role="alert">
            <.icon name="warning-orange" class="inline-block w-12 h-7 sm:h-8"/>
            <span class="pl-4 text-sm md:text-base font-sans">
              <span style="font-bold font-sans">Note:</span>
              You already have a text watermark saved. If you choose to save an image watermark,
              this will replace your currently saved text watermark.</span>
        </div>
      <% end %>

      <%= if @case == :text and watermark_type(@global_gallery_settings) == :image do  %>
        <div class="flex items-start justify-between px-6 py-3 errorWatermarkMessage sm:items-center mb-7" role="alert">
            <.icon name="warning-orange" class="inline-block w-12 h-7 sm:h-8"/>
            <span class="pl-4 text-sm md:text-base">
              <span style="font-bold font-sans">Note:</span> You already have an image watermark saved.
              If you choose to save a text watermark, this will replace your currently saved image watermark.
            </span>
        </div>
      <% end %>

      <div class="flex justify-start mb-4">
          <button id="waterMarkImage" class={classes("watermarkTypeBtn", %{"active" => @case == :image})} phx-click="image_case" >
          <span>Image</span>
          </button>
          <button id="waterMarkText" class={classes("watermarkTypeBtn", %{"active" => @case == :text})} phx-click="text_case" >
          <span>Text</span>
          </button>
      </div>

      <%= if @case == :image do %>
        <div class="overflow-hidden dragDrop__wrapper">
            <form id="dragDrop-form" phx-submit="save" phx-change="validate_image_input" >
              <label>
                  <div id="dropzone" phx-hook="DragDrop" phx-drop-target={@uploads.image.ref} class="flex flex-col items-center justify-center gap-8 cursor-pointer dragDrop">
                    <img src={Routes.static_path(PicselloWeb.Endpoint, "/images/drag-drop-img.png")} width="76" height="76"/>
                    <div class="dragDrop__content">
                        <p class="font-bold">
                          <span class="font-bold text-base-300">Drop images or </span>
                          <span class="cursor-pointer primary">Browse
                            <%= live_file_input @uploads.image, class: "dragDropInput" %>
                          </span>
                        </p>
                        <p class="text-center">Supports PNG</p>
                    </div>
                  </div>
              </label>
            </form>
        </div>

        <%= for entry <- @uploads.image.entries do %>
          <div class="flex items-center justify-between w-full uploadingList__wrapper watermarkProgress pt-7" id={entry.uuid}>
              <p class="font-bold font-sans"><%= if entry.progress == 100, do: "Upload complete!", else: "Uploading..." %></p>

              <progress class="grid-cols-1 font-sans" value={entry.progress} max="100"><%= entry.progress %>%</progress>
          </div>
        <% end %>
      <% else %>

        <div>
          <img src={"#{@watermarked_preview_path && PhotoStorage.path_to_url(@watermarked_preview_path)}"} class={classes("", %{"hidden" => !@show_preview})} />
          <.form let={f} for={@changeset} phx-change="validate_text_input"  class="mt-5 font-sans" id="textWatermarkForm">
            <div class="gallerySettingsInput flex flex-row p-1">
              <%= text_input f, :watermark_text , placeholder: "Enter your watermark text here", class: "bg-base-200 rounded-lg p-2 w-full focus:outline-inherit mr-1" %>
              <a class={classes("btn-secondary bg-base-200 flex items-center ml-auto whitespace-nowrap", %{"hidden" => !@ready_to_save})} phx-click="preview_watermark"><%= preview_button_text(@show_preview) %></a>
              <%= error_tag f, :watermark_text %>
            </div>
          </.form>
        </div>
      <% end %>

      <div class="flex flex-col gap-2 py-6 lg:flex-row-reverse">
        <button class={"btn-primary #{!@ready_to_save && 'cursor-not-allowed'}"} phx-click="save_watermark" disabled={!@ready_to_save}>Save</button>
        <button class="btn-secondary" phx-click="close" phx-value-ref={entry && entry.ref}><span>Cancel</span></button>
      </div>
    </.card>
    """
  end

  defp nav_item(assigns) do
    assigns = Enum.into(assigns, %{event_name: nil, print_price_section?: nil})

    ~H"""
    <div class={"bg-base-250/10 font-bold rounded-lg cursor-pointer grid-item"}>
      <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" phx-click={@event_name}>
          <a class="flex w-full">
            <div class="flex items-center justify-start">
                <div class="justify-start ml-3">
                <span class={"#{@open? && !@print_price_section? && 'text-blue-planning-300'}"}><%= @item_title %></span>
                </div>
            </div>
          </a>
      </div>
      <%= if @print_price_section? do %>
        <div class={"#{@print_price_section? && 'bg-base-200'} flex items-center lg:h-11 pr-4 lg:pl-2 pl-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-b-lg border border-base-220 text-ellipsis hover:text-blue-planning-300"} phx-click={@event_name}>
            <a class="flex w-full">
              <div class="flex items-center justify-start">
                  <div class="justify-start ml-3">
                    <span class={"#{@open? && 'text-blue-planning-300'}"}>Print Pricing</span>
                  </div>
              </div>
            </a>
        </div>
      <% end %>
      <%= if(@open?) do %>
        <span class="arrow show lg:block hidden">
          <svg class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10" style="">
            <use href="/images/icons.svg#arrow-filled"></use>
          </svg>
        </span>
      <% end %>
    </div>
    """
  end

  defp remove_button(assigns) do
    ~H"""
    <button phx-click="delete" class="pl-7">
      <.icon name="remove-icon" class="w-4 h-4 ml-1 text-base-250"/>
    </button>
    """
  end
end
