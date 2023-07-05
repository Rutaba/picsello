defmodule PicselloWeb.GalleryLive.GlobalSettings.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Galleries, GlobalSettings}

  alias Galleries.{PhotoProcessing.ProcessingManager, Workers.PhotoStorage}
  alias PicselloWeb.GalleryLive.GlobalSettings.{ProductComponent, PrintProductComponent}
  alias GlobalSettings.Gallery, as: GSGallery
  alias Ecto.Changeset
  alias Phoenix.PubSub
  require Logger

  import PicselloWeb.JobLive.Shared, only: [assign_existing_uploads: 2]

  @upload_options [
    accept: ~w(.png image/png),
    max_entries: 1,
    max_file_size: String.to_integer(Application.compile_env(:picsello, :photo_max_file_size)),
    auto_upload: true,
    external: &__MODULE__.presign_image/2,
    progress: &__MODULE__.handle_image_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  @global_watermarked_path Application.compile_env!(:picsello, :global_watermarked_path)

  @impl true
  def mount(params, _session, %{assigns: %{current_user: current_user}} = socket) do
    %{organization_id: organization_id} = current_user

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "preview_watermark:#{organization_id}")
    end

    socket
    |> is_mobile(params)
    |> assign(galleries: [])
    |> assign_global_settings()
    |> assign_options()
    |> assign(total_days: 0)
    |> assign(:case, :image)
    |> assign(is_saved: false)
    |> then(fn %{assigns: %{gs_gallery: gs_gallery}} = socket ->
      socket
      |> assign(is_never_expires: gs_gallery.expiration_days == 0)
      |> assign(price_changeset: GSGallery.price_changeset(gs_gallery))
    end)
    |> assign_default_changeset()
    |> allow_upload(:image, @upload_options)
    |> ok()
  end

  @impl true
  def handle_params(%{"section" => "products"}, _uri, socket),
    do: new_section(socket, product_section?: true)

  def handle_params(%{"section" => "print_product", "product_id" => product_id}, _uri, socket),
    do:
      socket
      |> assign(:product, GlobalSettings.gallery_product(product_id))
      |> new_section(product_section?: true, print_price_section?: true)

  def handle_params(%{"section" => "watermark"}, _uri, socket),
    do: new_section(socket, watermark_section?: true)

  def handle_params(%{"section" => "digital_pricing"}, _uri, socket),
    do: new_section(socket, digital_pricing_section?: true)

  def handle_params(_params, _uri, %{assigns: %{is_mobile: is_mobile}} = socket),
    do: new_section(socket, expiration_date_section?: !is_mobile)

  @impl true
  def handle_event(
        "save",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    {total_days, {d, m, y}} = total_days(day, month, year)
    date_in_text = Enum.map_join([{d, "day"}, {m, "month"}, {y, "year"}], &date_part_in_text(&1))

    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, Go back",
      confirm_event: "set_expire",
      confirm_label: "Yes, set expiration date",
      icon: "warning-orange",
      subtitle:
        "All new galleries will expire #{date_in_text}after their shoot date. When a gallery expires, a client will not be able to access it again unless you re-enable the individual gallery.",
      title: "Set Galleries to Never Expire?",
      payload: %{total_days: total_days}
    })
    |> noreply()
  end

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

  def handle_event("preview_watermark", %{}, %{assigns: %{show_preview: false}} = socket) do
    %{assigns: %{current_user: current_user, changeset: changeset}} = socket

    process_watermark_preview(
      current_user,
      :text,
      Changeset.get_change(changeset, :watermark_text)
    )

    noreply(socket)
  end

  def handle_event("preview_watermark", %{}, %{assigns: %{show_preview: true}} = socket) do
    socket |> assign(show_preview: false) |> assign_watermark_preview() |> noreply()
  end

  def handle_event(
        "save_watermark",
        _params,
        %{
          assigns: %{
            changeset: %{changes: changes},
            current_user: %{organization_id: organization_id} = current_user,
            gs_gallery: gs_gallery,
            uploads: uploads
          }
        } = socket
      ) do
    changes = Map.merge(changes, %{organization_id: organization_id, global_watermark_path: nil})

    gs_gallery
    |> GlobalSettings.save(changes)
    |> case do
      {:ok, gs_gallery} ->
        process_watermark_preview(
          current_user,
          gs_gallery.watermark_type,
          gs_gallery.watermark_text,
          true
        )

        uploads
        |> Map.update(:image, [], &Map.put(&1, :entries, []))
        |> assign_existing_uploads(socket)
        |> assign(gs_gallery: gs_gallery)
        |> assign_default_changeset()
        |> put_flash(:success, "Watermark Updated!")
        |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Failed to Update Watermark") |> noreply()
    end
  end

  def handle_event("image_case", _params, socket) do
    socket
    |> assign(:case, :image)
    |> assign_default_changeset()
    |> noreply()
  end

  def handle_event("text_case", _params, socket) do
    socket
    |> assign(:case, :text)
    |> assign_default_changeset()
    |> noreply()
  end

  def handle_event("validate_image_input", _, %{assigns: %{uploads: uploads}} = socket) do
    case uploads.image.entries do
      [%{valid?: false, ref: ref}] -> socket |> cancel_upload(:photo, ref) |> noreply
      _ -> noreply(socket)
    end
  end

  def handle_event(
        "validate_text_input",
        %{"gallery" => %{"watermark_text" => watermark_text}},
        %{assigns: %{gs_gallery: global_settings}} = socket
      ) do
    socket
    |> assign(
      :changeset,
      GSGallery.text_watermark_change(global_settings, %{
        watermark_text: watermark_text,
        watermark_type: :text
      })
    )
    |> noreply
  end

  def handle_event("close", _, socket) do
    socket
    |> assign_default_changeset()
    |> noreply()
  end

  def handle_event("back_to_menu", _, socket), do: new_section(socket)
  def handle_event("back_to_products", _, socket), do: new_section(socket, product_section?: true)

  def handle_event("select_component", %{"section" => ""}, socket),
    do: patch(socket)

  def handle_event("select_component", %{"section" => section}, socket),
    do: patch(socket, section: section)

  def handle_event(
        "validate_days",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    {total_days, {d, m, y}} = total_days(day, month, year)

    socket
    |> assign(total_days: total_days, day: d, month: m, year: y, is_saved: true)
    |> noreply()
  end

  def handle_event("validate_days", _params, socket), do: noreply(socket)

  def handle_event(
        "toggle-never-expires",
        _,
        %{assigns: %{is_never_expires: is_never_expires}} = socket
      ) do
    socket |> assign(is_never_expires: !is_never_expires) |> noreply()
  end

  def handle_event(
        "validate_price",
        %{"gallery" => params},
        %{assigns: %{gs_gallery: gs_gallery}} = socket
      ) do
    price_changeset = GSGallery.price_changeset(gs_gallery, params)

    price_changeset
    |> case do
      %{valid?: true} = price_changeset ->
        {:ok, _} = GlobalSettings.save(price_changeset)

        put_flash(socket, :success, "Setting Updated")

      _ ->
        socket
    end
    |> assign(price_changeset: price_changeset)
    |> noreply()
  end

  @impl true
  def handle_info({:preview_watermark, %{"isSavePreview" => true}}, socket) do
    socket
    |> assign_global_settings()
    |> assign_watermark_preview()
    |> noreply()
  end

  def handle_info({:preview_watermark, %{"watermarkedPreviewPath" => path}}, socket) do
    socket
    |> assign(show_preview: true)
    |> assign(:watermarked_preview_path, path)
    |> noreply()
  end

  @never_expire_days 0
  def handle_info({:confirm_event, "never_expire"}, socket) do
    socket
    |> update_expired_at(@never_expire_days)
    |> assign(day: 0, month: 0, year: 0)
    |> assign(is_saved: false)
    |> process_defaults
  end

  def handle_info(
        {:confirm_event, "set_expire", %{total_days: total_days}},
        socket
      ) do
    socket
    |> update_expired_at(total_days)
    |> assign(is_never_expires: false)
    |> assign(is_saved: false)
    |> process_defaults
  end

  def handle_info({:confirm_event, "delete_watermarks"}, socket) do
    %{assigns: %{gs_gallery: gs_gallery}} = socket

    gs_gallery
    |> GlobalSettings.delete_watermark()
    |> assign_updated_settings(socket)
    |> assign(:case, :image)
    |> process_defaults()
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

  defp process_defaults(socket) do
    socket
    |> close_modal()
    |> put_flash(:success, "Setting Updated")
    |> noreply()
  end

  def presign_image(
        image,
        %{
          assigns: %{
            current_user: %{organization_id: organization_id},
            gs_gallery: gs_gallery
          }
        } = socket
      ) do
    key = GSGallery.watermark_path(organization_id)

    sign_opts = [
      expires_in: 600,
      bucket: @bucket,
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

    {:ok, meta,
     socket
     |> assign(
       :changeset,
       GSGallery.image_watermark_change(gs_gallery, %{
         watermark_name: image.client_name,
         watermark_size: image.client_size
       })
     )}
  end

  def handle_image_progress(:image, %{done?: false}, socket), do: noreply(socket)

  def handle_image_progress(:image, _entry, socket),
    do: __MODULE__.handle_event("save_watermark", %{}, socket)

  defp update_expired_at(
         %{assigns: %{gs_gallery: gs_gallery}} = socket,
         days
       ) do
    gs_gallery
    |> GlobalSettings.save(%{expiration_days: days})
    |> assign_updated_settings(socket)
  end

  defp date_part_in_text({count, _date_part}) when count <= 0, do: ""

  defp date_part_in_text({count, date_part}) when count > 0,
    do: "#{count} #{date_part}#{(count > 1 && 's') || ""} "

  defp total_days(day, month, year) do
    {d, m, y} = date_parts = {to_int(day), to_int(month), to_int(year)}

    {d + m * 30 + y * 365, date_parts}
  end

  defp assign_options(
         %{
           assigns: %{
             gs_gallery: %{expiration_days: expiration_days}
           }
         } = socket
       )
       when not is_nil(expiration_days) do
    {day, month, year} = GSGallery.explode_days(expiration_days)

    socket |> assign(day: day, month: month, year: year)
  end

  defp assign_options(socket), do: assign(socket, day: "day", month: "month", year: "year")

  defp assign_updated_settings({:ok, %GSGallery{} = gs_gallery}, socket),
    do: assign(socket, gs_gallery: gs_gallery)

  defp assign_global_settings(%{assigns: assigns} = socket) do
    %{current_user: %{organization_id: organization_id}} = assigns
    assign(socket, :gs_gallery, GlobalSettings.get_or_add(organization_id))
  end

  defp assign_watermark_preview(
         %{
           assigns: %{
             gs_gallery: %{
               watermark_type: :text,
               global_watermark_path: global_watermark_path
             }
           }
         } = socket
       ) do
    assign(
      socket,
      :watermarked_preview_path,
      global_watermark_path
    )
  end

  defp assign_watermark_preview(socket), do: assign(socket, :watermarked_preview_path, nil)

  defp assign_default_changeset(%{assigns: %{gs_gallery: gs_gallery}} = socket) do
    socket
    |> assign(
      :changeset,
      gs_gallery
      |> GSGallery.watermark_change()
      |> Map.put(:valid?, false)
    )
    |> assign_watermark_preview()
    |> assign(show_preview: false)
  end

  defp assign_title(%{assigns: assigns} = socket), do: assign(socket, :title, title(assigns))

  defp title(%{watermark_section?: true}), do: "Watermark"
  defp title(%{digital_pricing_section?: true}), do: "Digital Pricing"
  defp title(%{print_price_section?: true}), do: "Print Pricing"
  defp title(%{expiration_date_section?: true}), do: "Global Expiration Date"
  defp title(%{product_section?: true}), do: "Product Settings & Prices"
  defp title(_), do: "Gallery Settings"

  defp to_int(""), do: 0
  defp to_int(value), do: String.to_integer(value)

  @sections ~w(print_price_section? product_section? expiration_date_section? watermark_section? digital_pricing_section?)a
  defp new_section(socket, opts \\ []) do
    @sections
    |> Enum.reduce(socket, &assign(&2, &1, false))
    |> assign(opts)
    |> assign_title()
    |> noreply()
  end

  defp process_watermark_preview(current_user, type, text, is_save_preview \\ false) do
    ProcessingManager.update_watermark(%GSGallery.Photo{
      is_save_preview: is_save_preview,
      id: UUID.uuid4(),
      organization_id: current_user.organization_id,
      original_url: @global_watermarked_path,
      watermark_type: type,
      text: text
    })
  end

  defp watermark_type(%{watermark_type: :image}), do: :image
  defp watermark_type(%{watermark_type: :text}), do: :text
  defp watermark_type(_), do: :undefined

  defp patch(socket, opts \\ []) do
    socket
    |> push_patch(to: Routes.gallery_global_settings_index_path(socket, :edit, opts))
    |> noreply()
  end

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

  defp section(%{digital_pricing_section?: true} = assigns) do
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

  defp section(%{expiration_date_section?: true} = assigns) do
    ~H"""
      <h1 class="text-2xl font-bold mt-6 md:block hidden">Global Expiration Date</h1>
      <.card color="blue-planning-300" icon="three-people" title="Expiration Date" badge={0} class="cursor-pointer mt-8" >
          <p class="my-2 text-base-250">
            Add a global expiration date that will be the default setting across all your new galleries.
            This will not affect your pre-existing galleries. If your job doesn’t have a shoot date, the gallery
            for that job will default to <i>“Never Expires”</i>. New galleries will expire:
          </p>
          <.form :let={f} for={%{}} as={:global_expiration_days} phx-submit="save" phx-change="validate_days">
            <div class="items-center">
              <%= for {name, max, number, title} <- [{:day, 31, @day, "days,"}, {:month, 11, @month, "months,"}, {:year, 5, @year, "years after their shoot date."}] do %>
                <%= input f, name, type: :number_input, min: 0, max: max , value: if(number > 0, do: number),
                  placeholder: "1",
                  class: "border-blue-planning-300 mx-2 md:mx-3 w-20 cursor-pointer 'text-gray-400 cursor-default border-blue-planning-200",
                  disabled: @is_never_expires %>

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
                  disabled= {(@total_days == 0 && @is_never_expires == false) || @is_saved == false} >
                  Save
                </button>
            </div>
          </.form>
      </.card>
    """
  end

  defp section(%{watermark_section?: true, uploads: uploads} = assigns) do
    entry = Enum.at(uploads.image.entries, 0)
    assigns = Enum.into(assigns, %{entry: entry})

    ~H"""
    <h1 class={classes("text-2xl font-bold mt-6 md:block", %{"hidden" => @watermark_section?})}>Watermark</h1>
    <.card color="blue-planning-300" icon="three-people" title="Custom Watermark" badge={0} class="cursor-pointer mt-8" >
      <div class="flex justify-start mb-4">
        <.switch_button id="waterMarkImage" expected_case={:image} event="image_case" case={@case} />
        <.switch_button id="waterMarkText" expected_case={:text} event="text_case" case={@case} />
      </div>

      <.watermark_section {assigns} />

      <div class="flex flex-col gap-2 py-6 lg:flex-row-reverse">
        <%= unless @case == :image do %>
          <button class={"btn-primary #{!@changeset.valid? && 'cursor-not-allowed'}"} phx-click="save_watermark" disabled={!@changeset.valid?}>Save</button>
          <button class="btn-secondary" phx-click="close"><span>Cancel</span></button>
        <% end %>
      </div>
    </.card>
    """
  end

  defp section(%{product_section?: true, print_price_section?: false} = assigns) do
    ~H"""
      <.live_component id="products" module={ProductComponent} organization_id={@current_user.organization_id} />
    """
  end

  defp section(%{product_section?: true, print_price_section?: true} = assigns) do
    ~H"""
      <.live_component id="product_prints" module={PrintProductComponent} product={@product} />
    """
  end

  defp section(assigns), do: ~H[<div></div>]

  defp watermark_section(%{case: :image} = assigns) do
    ~H"""
    <%= if @gs_gallery.watermark_type == :image && @gs_gallery.global_watermark_path do %>
      <img src={"#{PhotoStorage.path_to_url(@gs_gallery.global_watermark_path)}"} />
    <% end %>

    <.watermark_name_delete name={@gs_gallery.watermark_name} case={@case} watermark_type={@gs_gallery.watermark_type}>
      <p><%= @gs_gallery.watermark_size && filesize(@gs_gallery.watermark_size) %></p>
    </.watermark_name_delete>
    <.existing_watermark_message {assigns} />

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
    """
  end

  defp watermark_section(%{case: :text} = assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <img src={"#{@watermarked_preview_path && PhotoStorage.path_to_url(@watermarked_preview_path)}"} />

      <.watermark_name_delete name={@gs_gallery.watermark_text} case={@case} watermark_type={@gs_gallery.watermark_type}>
        <.icon name="typography-symbol" class="w-3 h-3.5 ml-1 fill-current"/>
      </.watermark_name_delete>
      <.existing_watermark_message {assigns} />

      <.form :let={f} for={@changeset} phx-change="validate_text_input" phx-submit="save_watermark" class="mt-5 font-sans" id="textWatermarkForm">
        <div class="gallerySettingsInput flex flex-row p-1">
          <%= text_input f, :watermark_text , placeholder: "Enter your watermark text here", class: "bg-base-200 rounded-lg p-2 w-full focus:outline-inherit mr-1" %>
          <a class={classes("btn-secondary bg-base-200 flex items-center ml-auto whitespace-nowrap", %{"hidden" => !@changeset.valid?})} phx-click="preview_watermark"><%= @show_preview && "Hide Preview" || "Show Preview" %></a>
          <%= error_tag f, :watermark_text %>
        </div>
      </.form>
    </div>
    """
  end

  defp switch_button(assigns) do
    ~H"""
    <button id={@id} class={classes("watermarkTypeBtn", %{"active" => @case == @expected_case})} phx-click={@event} >
      <span><%= @expected_case |> Atom.to_string() |> String.capitalize() %></span>
    </button>
    """
  end

  defp existing_watermark_message(%{case: w_case, gs_gallery: gs_gallery} = assigns) do
    text_watermarked? = w_case == :image and watermark_type(gs_gallery) == :text
    assigns = Enum.into(assigns, %{current_watermark: (text_watermarked? && "text") || "image"})

    ~H"""
      <div id="any" phx-update="replace" class={"flex items-start justify-between px-6 py-3 errorWatermarkMessage sm:items-center mb-7 #{watermark_type(@gs_gallery) in [@case, :undefined] && 'hidden'}"} role="alert">
        <.icon name="warning-orange" class="inline-block w-12 h-7 sm:h-8"/>
        <span class="pl-4 text-sm md:text-base font-sans">
        <span style="font-bold font-sans">Note:</span>
        You already have a <%= @current_watermark %> watermark saved. If you choose to save an <%= @current_watermark %>
        watermark, this will replace your currently saved <%= @current_watermark %> watermark.</span>
      </div>
    """
  end

  defp watermark_name_delete(%{case: type, watermark_type: type} = assigns) do
    ~H"""
      <div class="flex justify-between mb-8 mt-11 font-sans">
        <p><%= @name %></p>
        <div class="flex items-center">
          <%= render_slot @inner_block %>
          <button phx-click="delete" class="pl-7">
            <.icon name="remove-icon" class="w-4 h-4 ml-1 text-base-250"/>
          </button>
        </div>
      </div>
    """
  end

  defp watermark_name_delete(assigns), do: ~H[]

  defp nav_item(assigns) do
    assigns = Enum.into(assigns, %{event_name: nil, print_price_section?: nil})

    ~H"""
    <div class={"bg-base-250/10 font-bold rounded-lg cursor-pointer grid-item"}>
      <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" phx-value-section={@value} phx-click="select_component">
        <.nav_title title={@item_title} open?={@open? && !@print_price_section?} />
      </div>
      <%= if @print_price_section? do %>
        <div class={"#{@print_price_section? && 'bg-base-200'} flex items-center lg:h-11 pr-4 lg:pl-2 pl-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-b-lg border border-base-220 text-ellipsis hover:text-blue-planning-300"}>
          <.nav_title title="Print Pricing" open?={@open?} />
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
end
