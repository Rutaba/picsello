defmodule PicselloWeb.GalleryLive.GlobalSettings.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Repo, Galleries}
  alias Ecto.Multi

  alias Galleries.{PhotoProcessing.ProcessingManager, Workers.PhotoStorage}
  alias PicselloWeb.GalleryLive.GlobalSettings.{ProductComponent, PrintProductComponent}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Ecto.Changeset
  alias Phoenix.PubSub
  require Logger
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

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
  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    %{organization_id: organization_id} = current_user
    global_settings_gallery = Repo.get_by(GSGallery, organization_id: organization_id) || %GSGallery{}
    
    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "preview_watermark:#{current_user.id}")
      PubSub.subscribe(Picsello.PubSub, "save_watermark:#{current_user.id}")
    end

    socket
    |> assign(galleries: [])
    |> assign(global_settings_gallery: global_settings_gallery)
    |> assign(price_changeset: GSGallery.price_changeset(global_settings_gallery, %{}))
    |> assign_controls()
    |> assign_options()
    |> assign(is_saved: false)
    |> assign(total_days: 0)
    |> assign(:upload_bucket, @bucket)
    |> assign(:case, :image)
    |> assign(:ready_to_save, false)
    |> assign(show_preview: false)
    |> assign(:show_image_preview, true)
    |> assign(:watermarked_preview_path, nil)
    |> allow_upload(:image, @upload_options)
    |> ok()
  end

  @impl true
  def handle_params(%{"section" => "print_product", "product_id" => product_id}, _uri, socket),
    do:
      socket
      |> assign(:product, Picsello.GlobalSettings.gallery_product(product_id))
      |> assign(:show_side_nav, "print_product")
      |> assign_title()
      |> noreply()
  
  def handle_params(params, _uri, socket) do 
    show_side_nav = Map.get(params, "section")
    socket
    |> assign(:show_side_nav, show_side_nav)
    |> assign_title()
    |> noreply() 
  end

  @impl true
  def handle_event(
        "save",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    day_count = to_int(day)
    month_count = to_int(month)
    year_count = to_int(year)
    day_text = if day_count > 0, do: ngettext("1 day ", "%{count} days ", day_count), else: ""

    month_text =
      if month_count > 0, do: ngettext("1 month ", "%{count} months ", month_count), else: ""

    year_text =
      if year_count > 0, do: ngettext("1 year ", "%{count} years ", year_count), else: ""

    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, Go back",
      confirm_event: "set_expire",
      confirm_label: "Yes, set expiration date",
      icon: "warning-orange",
      subtitle:
        "All new galleries will expire #{day_text}#{month_text}#{year_text}after their shoot date. When a gallery expires, a client will not be able to access it again unless you re-enable the individual gallery.",
      title: "Set Galleries to Expire?",
      payload: %{total_days: day_count + month_count * 30 + year_count * 365}
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

    socket
    |> assign(total_days: total_days, day: day, month: month, year: year, is_saved: true)
    |> noreply()
  end

  def handle_event("validate_days", _params, socket), do: noreply(socket)

  def handle_event(
        "save",
        %{},
        %{assigns: %{is_never_expires: true}} = socket
      ) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, go back",
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
            changeset: %{changes: changes},
            current_user: %{organization_id: organization_id} = current_user,
            case: watermark_case,
            uploads: uploads
          }
        } = socket
      ) do
    changes = Map.put(changes, :organization_id, organization_id)

    socket
    |> settings_multi(changes)
    |> Multi.run(:save_galleries_watermark, fn _, %{global_settings: global_settings} ->
      params = build_params(global_settings)

      current_user
      |> galleries_by_setting_type(:watermark)
      |> Galleries.save_galleries_watermark(params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{global_settings: global_settings}} ->
        if watermark_case == :image do
          uploads = Map.update(uploads, :image, [], &Map.put(&1, :entries, []))
          assign(socket, uploads: uploads)
        else
          assign(socket, :show_image_preview, false)
        end
        |> assign(global_settings_gallery: global_settings)
        |> put_flash(:success, "Watermark Updated!")

      {:error, _} ->
        put_flash(socket, :error, "Failed to Update Watermark")
    end
    |> noreply()
  end

  @impl true
  def handle_event("delete", _, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_watermarks",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      subtitle:
        "Are you sure you wish to permanently delete your custom watermark? You can always add another one later.",
      title: "Delete watermark?"
    })
    |> noreply()
  end

  def handle_event("back_to_menu", _, socket), do: assign(socket, :show_side_nav, nil) |> noreply()

  def handle_event("select_component", %{"section" => nil}, socket),
    do: patch(socket)

  def handle_event("select_component", %{"section" => section}, socket),
    do: patch(socket, [section: section])

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
  def handle_event("back_to_products", _, socket), do: assign(socket, show_side_nav: "products") |> noreply()

  def handle_event(
        "validate_price",
        %{"gallery" => params},
        %{assigns: %{global_settings_gallery: settings}} = socket
      ) do
    price_changeset = GSGallery.price_changeset(settings, params)
    
    case price_changeset do
      %{valid?: true} ->
        socket
        |> update_galleries_prices(price_changeset)

        _ -> socket
    end
    |> assign(price_changeset: price_changeset)
    |> noreply()
  end

  defp update_galleries_prices(%{assigns: %{current_user: current_user}} = socket, changeset) do
    prices = current(changeset)
    attrs = [buy_all: prices.buy_all_price, download_each_price: prices.download_each_price]
    
    socket
    |> settings_multi(%{organization_id: current_user.organization.id})
    |> Multi.update_all(
      :update_package,
      current_user
      |> galleries_by_setting_type(:digital)
      |> Enum.map(& &1.id)
      |> Picsello.Packages.update_all_query(attrs),
      []
    )
    |> Ecto.Multi.insert_or_update(:insert_or_update, changeset)
    |> Repo.transaction()
    |> then(fn _ -> 
      socket
      |> put_flash(:success, "Setting Updated")
    end)
  end

  defp galleries_by_setting_type(%{organization_id: org_id}, value) do
    Galleries.list_shared_setting_galleries(org_id, to_string(value))
  end

  defp assign_options(
         %{
           assigns: %{
             global_settings_gallery: %{expiration_days: expiration_days}
           }
         } = socket
       )
       when not is_nil(expiration_days) do
      {day, month, year} = GSGallery.explode_days(expiration_days)  
    socket |> assign(day: day, month: month, year: year)
  end

  defp assign_options(socket) do
    socket |> assign(day: "day", month: "month", year: "year")
  end

  defp assign_title(%{assigns: %{show_side_nav: show_side_nav}} = socket) do 
    title = case show_side_nav do
      "expiration_date" -> "Global Expiration Date"
      "watermark" -> "Watermark"
      "products" -> "Print Pricing"
      "print_product" -> "Product Settings & Prices"
      "digital_pricing" -> "Digital Pricing"
      _ -> "Gallery Settings"  
    end

    socket |> assign(:title, title)
  end

  defp to_int(""), do: 0
  defp to_int(value), do: to_integer(value)

  defp assign_controls(%{assigns: %{global_settings_gallery: gs_g}} = socket)
       when not is_nil(gs_g),
       do: socket |> assign(is_never_expires: gs_g.expiration_days == 0)

  defp assign_controls(socket), do: socket |> assign(is_never_expires: true)

  defp assign_updated_settings({:ok, %{global_settings: ggs}}, socket),
    do: assign(socket, global_settings_gallery: ggs)

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
        %{assigns: %{global_settings_gallery: global_settings}} = socket
      ) do
    global_settings
    |> changeset(global_watermark_path: watermarked_preview_path)
    |> Repo.insert_or_update()
    |> then(fn {:ok, global_settings} ->
      socket |> assign(global_settings_gallery: global_settings) |> noreply()
    end)
  end

  @never_expire_days 0
  @impl true
  def handle_info(
        {:confirm_event, "never_expire"},
        socket
      ) do
    socket
    |> update_expired_at(@never_expire_days)
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> assign(is_saved: false)
    |> assign(day: 0, month: 0, year: 0)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_watermarks"},
        %{
          assigns: %{
            current_user: current_user
          }
        } = socket
      ) do
    socket
    |> settings_multi(%{
      watermark_type: nil,
      watermark_name: nil,
      watermark_text: nil,
      watermark_size: nil
    })
    |> Multi.run(:delete_watermarks, fn _, _ ->
      current_user
      |> galleries_by_setting_type(:watermark)
      |> Enum.map(& &1.id)
      |> Galleries.delete_multiple_watermarks()
    end)
    |> Repo.transaction()
    |> assign_updated_settings(socket)
    |> assign(:case, :image)
    |> assign_default_changeset()
    |> assign(:show_image_preview, false)
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "set_expire", %{total_days: total_days}},
        socket
      ) do
    socket
    |> update_expired_at(total_days)
    |> assign(is_never_expires: false)
    |> assign(is_saved: false)
    |> close_modal()
    |> put_flash(:success, "Setting Updated")
    |> noreply()
  end

  def handle_info({:select_print_prices, product}, socket) do
    socket
    |> assign(show_side_nav: "print_product")
    |> assign_title()
    |> assign(:product, product)
    |> noreply()
  end

  def handle_info({:back_to_products}, socket) do
    socket
    |> assign(show_side_nav: "products")
    |> assign_title()
    |> noreply()
  end

  defp update_expired_at(%{assigns: %{current_user: current_user}} = socket, days) do
    socket
    |> settings_multi(%{
      expiration_days: days,
      organization_id: current_user.organization_id
    })
    |> Multi.run(:update_expired_at, fn _, _ ->
      current_user
      |> galleries_by_setting_type(:expiration)
      |> Galleries.update_all(days)

      {:ok, ""}
    end)
    |> Repo.transaction()
    |> assign_updated_settings(socket)
  end

  def presign_image(
        image,
        %{
          assigns: %{current_user: %{organization_id: organization_id}}
        } = socket
      ) do
    key = GSGallery.watermark_path(organization_id)

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

  def handle_image_progress(:image, image, %{assigns: %{current_user: current_user}} = socket) do
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
      current_user.organization_id
    )

    socket
    |> assign_image_watermark_change(image)
    |> noreply()
  end

  defp build_params(%{watermark_type: watermark_type} = global_settings) do
    case watermark_type do
      :image ->
        %{
          name: global_settings.watermark_name,
          size: global_settings.watermark_size,
          type: :image
        }

      :text ->
        %{text: global_settings.watermark_text, type: :text}
    end
  end

  defp assign_image_watermark_change(
         %{assigns: %{global_settings_gallery: global_settings}} = socket,
         %{client_name: client_name, client_size: client_size}
       ) do
    socket
    |> assign(
      :changeset,
      GSGallery.image_watermark_change(global_settings, %{
        watermark_name: client_name,
        watermark_size: client_size
      })
    )
    |> assign(:show_image_preview, true)
    |> then(&assign(&1, :ready_to_save, &1.assigns.changeset.valid?))
  end

  defp assign_default_changeset(
         %{assigns: %{global_settings_gallery: global_settings_gallery}} = socket
       ) do
    socket
    |> assign(
      :changeset,
      GSGallery.watermark_change(global_settings_gallery)
    )
    |> assign(show_preview: false)
  end

  defp handle_image_validation(%{assigns: %{uploads: uploads}} = socket) do
    case uploads.image.entries do
      %{valid?: false, ref: ref} -> cancel_upload(socket, :photo, ref)
      _ -> socket
    end
  end

  defp assign_text_watermark_change(
         %{assigns: %{global_settings_gallery: global_settings}} = socket,
         %{"gallery" => %{"watermark_text" => watermark_text}}
       ) do
    global_settings
    |> GSGallery.text_watermark_change(%{watermark_text: watermark_text, watermark_type: :text})
    |> then(fn %{valid?: valid?} = changeset ->
      socket
      |> assign(:changeset, changeset)
      |> assign(:ready_to_save, valid?)
    end)
  end

  defp preview_button_text(true), do: "Hide Preview"
  defp preview_button_text(false), do: "Show Preview"

  defp watermark_type(%{watermark_type: :image}), do: :image
  defp watermark_type(%{watermark_type: :text}), do: :text
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

  defp section(%{show_side_nav: "digital_pricing"} = assigns) do
    ~H"""
      <h1 class="text-2xl font-bold mt-6 md:block">Digital Pricing</h1>
      <span class="text-base-250">Adjust on a per digital image and a "buy them all" option below. Defaults provided are our base recommendations but you know your clients and business best. And again, you can also adjust on an individual lead, package, or job level.</span>
      <.form :let={f} for={@price_changeset} phx-change="validate_price">
        <div class="grid gap-8 lg:grid-cols-2 grid-cols-1 mt-10">
          <div>
            <span class="text-xl font-bold">Single Image</span>
            <div class="flex flex-col items-center border p-3 rounded-md border-base-250 mt-4 md:h-28 h-32">
              <div class="flex items-center">
                <div class="flex flex-col md:pr-4">
                  <h1 class="text-xl font-bold">Pricing per image:</h1>
                  <span class="text-sm text-base-250 italic">Remember, this profit goes straight to you and your business so price fairly - for you and your clients!</span>
                </div>
                <%= input(f, :download_each_price, class: "w-full w-24 text-lg text-center border border-blue-planning-300 text-base-300", phx_debounce: 1000, phx_hook: "PriceMask") %>
              </div>  
              <%= if message = @price_changeset.errors[:download_each_price] do %>
                <div class="flex md:py-1 ml-auto text-red-sales-300 text-sm"><%= translate_error(message) %></div>
              <% end %>
            </div>
          </div>
          <div>
            <span class="text-xl font-bold">Buy them all</span>
            <div class="flex flex-col items-center border p-3 rounded-md border-base-250 mt-4 md:h-28 h-32">
              <div class="flex items-center">
                <div class="flex flex-col md:pr-4">
                  <h1 class="text-xl font-bold">Pricing for all images:</h1>
                  <span class="text-sm text-base-250 italic">Remember, this profit goes straight to you and your business so price fairly - for you and your clients!</span>
                </div>
                <%= input(f, :buy_all_price, class: "w-full w-24 text-lg text-center ml-auto border border-blue-planning-300 text-base-300", phx_debounce: 1000, phx_hook: "PriceMask") %>
              </div>
              <%= if message = @price_changeset.errors[:buy_all_price] do %>
                <div class="flex ml-auto md:py-1 text-red-sales-300 text-sm"><%= translate_error(message) %></div>
              <% end %>
            </div>
          </div>
        </div>
      </.form>
    """
  end

  defp section(%{show_side_nav: "expiration_date"} = assigns) do
    ~H"""
      <h1 class={classes("text-2xl font-bold mt-6 md:block", %{"hidden" => @show_side_nav == "expiration_date"})}>Global Expiration Date</h1>
      <.card color="blue-planning-300" icon="three-people" title="Expiration Date" badge={0} class="cursor-pointer mt-8" >
          <p class="my-2 text-base-250">
            Add a global expiration date that will be the default setting across all your new galleries.
            This will not affect your pre-existing galleries. If your job doesn’t have a shoot date, the gallery
            for that job will default to <i>“Never Expires”</i>. New galleries will expire:
          </p>
          <.form :let={f} for={%{}} as={:global_expiration_days} phx-submit="save" phx-change="validate_days">
            <div class="items-center">
              <%= for {name, max, number, title} <- [{:day, 31, @day, "days,"}, {:month, 11, @month, "months,"}, {:year, 5, @year, "years after gallery creation date."}] do %>
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
                  disabled= {(@total_days == 0 && @is_never_expires == false )  or @is_saved == false} >
                  Save
                </button>
            </div>
          </.form>
      </.card>
    """
  end

  defp section(%{show_side_nav: "watermark", uploads: uploads} = assigns) do
    entry = Enum.at(uploads.image.entries, 0)
    assigns = Enum.into(assigns, %{entry: entry})

    ~H"""
    <h1 class={classes("text-2xl font-bold mt-6 md:block", %{"hidden" => @show_side_nav == "watermark"})}>Watermark</h1>
    <.card color="blue-planning-300" icon="three-people" title="Custom Watermark" badge={0} class="cursor-pointer mt-8" >
      <%= if @case == :image and @show_image_preview do  %>

        <img src={"#{@global_settings_gallery && @global_settings_gallery.global_watermark_path && PhotoStorage.path_to_url(@global_settings_gallery.global_watermark_path)}"} />
        <%= if watermark_type(@global_settings_gallery) == :image do %>
          <.watermark_name_delete name={@global_settings_gallery.watermark_name}>
            <p><%= filesize(@global_settings_gallery.watermark_size) %></p>
          </.watermark_name_delete>
        <% end %>
      <% end %>

      <%= if @case == :image and watermark_type(@global_settings_gallery) == :text do  %>
        <div class="flex items-start justify-between px-6 py-3 errorWatermarkMessage sm:items-center mb-7" role="alert">
            <.icon name="warning-orange" class="inline-block w-12 h-7 sm:h-8"/>
            <span class="pl-4 text-sm md:text-base font-sans">
              <span style="font-bold font-sans">Note:</span>
              You already have a text watermark saved. If you choose to save an image watermark,
              this will replace your currently saved text watermark.</span>
        </div>
      <% end %>

      <%= if @case == :text and watermark_type(@global_settings_gallery) == :image do  %>
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

        <%= for e <- @uploads.image.entries do %>
          <div class="flex items-center justify-between w-full uploadingList__wrapper watermarkProgress pt-7" id={e.uuid}>
            <p class="font-bold font-sans"><%= if e.progress == 100, do: "Upload complete!", else: "Uploading..." %></p>
            <progress class="grid-cols-1 font-sans" value={e.progress} max="100"><%= e.progress %>%</progress>
          </div>
        <% end %>

      <% else %>
        <div>
          <img src={"#{@watermarked_preview_path && PhotoStorage.path_to_url(@watermarked_preview_path)}"} class={classes(%{"hidden" => !@show_preview})} />
          <%= if watermark_type(@global_settings_gallery) == :text do  %>
            <.watermark_name_delete name={@global_settings_gallery.watermark_text}>
              <.icon name="typography-symbol" class="w-3 h-3.5 ml-1 fill-current"/>
            </.watermark_name_delete>
          <% end %>
          <.form :let={f} for={@changeset} phx-change="validate_text_input" phx-submit="save_watermark" class="mt-5 font-sans" id="textWatermarkForm">
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
        <button class="btn-secondary" phx-click="close" phx-value-ref={@entry && @entry.ref}><span>Cancel</span></button>
      </div>
    </.card>
    """
  end

  defp section(%{show_side_nav: "products"} = assigns) do
    ~H"""
      <.live_component id="products" module={ProductComponent} organization_id={@current_user.organization_id} />
    """
  end

  defp section(%{show_side_nav: "print_product"} = assigns) do
    ~H"""
      <.live_component id="print_product" module={PrintProductComponent} product={@product} />
    """
  end

  defp section(assigns), do: ~H[<div></div>]

  defp watermark_name_delete(assigns) do
    ~H"""
      <div class="flex justify-between mb-8 mt-11 font-sans">
        <p><%= @name %></p>
        <div class="flex items-center">
          <%= render_slot @inner_block %>
          <.remove_button />
        </div>
      </div>
    """
  end

  defp nav_item(assigns) do
    assigns = Enum.into(assigns, %{event_name: nil})

    ~H"""
    <div class={"bg-base-250/10 font-bold rounded-lg cursor-pointer grid-item"}>
      <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" phx-value-section={@value} phx-click="select_component">
        <.nav_title title={@item_title} open?={@open? && @show_side_nav !== "print_product"} />
      </div>
      <%= if @value == "products" && @show_side_nav == "print_product" do %>
        <div class={classes("flex items-center lg:h-11 pr-4 lg:pl-2 pl-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-b-lg border border-base-220 text-ellipsis hover:text-blue-planning-300", %{"bg-base-200" => @show_side_nav == "print_product"})}>
          <.nav_title title="Print Pricing" open?={@open?} />
        </div>
      <% end %>
      <%= if(@open?) do %>
        <span class="arrow show lg:block hidden">
          <svg class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10">
            <use href="/images/icons.svg#arrow-filled"></use>
          </svg>
        </span>
      <% end %>
    </div>
    """
  end

  defp nav_title(assigns) do
    ~H"""
    <a class="flex w-full">
      <div class="flex items-center justify-start">
          <div class="justify-start ml-3">
            <span class={"#{@open? && 'text-blue-planning-300'}"}><%= @title %></span>
          </div>
      </div>
    </a>
    """
  end

  defp remove_button(assigns) do
    ~H"""
    <button phx-click="delete" class="pl-7">
      <.icon name="remove-icon" class="w-4 h-4 ml-1 text-base-250"/>
    </button>
    """
  end

  defp date_input(assigns) do
    ~H"""
      <%= input @f, @name, type: :number_input, min: 0, max: @max , value: if(@number > 0, do: @number),
      placeholder: "1",
      class: "border-blue-planning-300 mx-2 md:mx-3 w-20 cursor-pointer 'text-gray-400 cursor-default border-blue-planning-200",
      disabled: @is_never_expires %>
    """
  end

  defp changeset(gs \\ nil, attrs), do: Changeset.change(gs || %GSGallery{}, attrs)

  def settings_multi(socket, attrs, multi \\ Multi.new())

  def settings_multi(%{assigns: %{global_settings_gallery: %{id: nil}}}, attrs, multi) do
    Multi.insert(multi, :global_settings, changeset(attrs))
  end

  def settings_multi(%{assigns: %{global_settings_gallery: global_settings}}, attrs, multi) do
    Multi.update(multi, :global_settings, changeset(global_settings, attrs))
  end

  defp patch(socket, opts \\ []) do
    socket
    |> push_patch(to: Routes.gallery_global_settings_index_path(socket, :edit, opts))
    |> noreply()
  end
end
