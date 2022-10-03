defmodule PicselloWeb.GalleryLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.Galleries.Gallery
  require Ecto.Query
  alias Ecto.Query
  alias Picsello.{Galleries, Repo, Messages}

  defmodule Pagination do
    @moduledoc false
    defstruct first_index: 1,
              last_index: 4,
              total_count: 0,
              limit: 4,
              after: nil,
              before: nil
  end

  @impl true
  def mount(
        _params,
        _session,
        socket
      ) do
    socket
    |> assign_new(:pagination, fn -> %Pagination{} end)
    |> put_assigns()
    |> ok()
  end

  @impl true
  def handle_params(%{"is_gallery_created" => "true", "job_id" => job_id}, _uri, socket) do
    socket
    |> PicselloWeb.SuccessComponent.open(%{
      title: "Gallery Created!",
      subtitle: "Hooray! Your gallery has been created. you are now ready to upload photos.",
      success_label: "View new job",
      success_event: "view-job",
      close_label: "Great! Close window.",
      payload: %{job_id: job_id}
    })
    |> noreply()
  end

  def handle_params(_params, _uri, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_info(
        {:message_composed, changeset},
        %{
          assigns: %{
            current_user: %{organization: %{name: organization_name}},
            job: %{id: job_id}
          }
        } = socket
      ) do
    flash =
      changeset
      |> Ecto.Changeset.change(job_id: job_id, outbound: false, read_at: nil)
      |> Ecto.Changeset.apply_changes()
      |> Repo.insert()
      |> case do
        {:ok, message} ->
          Messages.notify_inbound_message(message, PicselloWeb.Helpers)

          &PicselloWeb.ConfirmationComponent.open(&1, %{
            title: "Contact #{organization_name}",
            subtitle: "Thank you! Your message has been sent. We’ll be in touch with you soon.",
            icon: nil,
            confirm_label: "Send another",
            confirm_class: "btn-primary",
            confirm_event: "send_another"
          })

        {:error, _} ->
          &(&1 |> close_modal() |> put_flash(:error, "Message not sent."))
      end

    socket |> flash.() |> noreply()
  end

  def handle_info({:success_event, "view-job", %{job_id: job_id}}, socket) do
    socket
    |> push_redirect(to: Routes.job_path(socket, :jobs, job_id))
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete_gallery"},
        %{assigns: %{gallery_id: gallery_id}} = socket
      ) do
    gallery_id = String.to_integer(gallery_id)
    {:ok, _} = Galleries.delete_gallery_by_id(gallery_id)

    socket
    |> close_modal()
    |> put_assigns()
    |> put_flash(:success, "Gallery deleted successfully")
    |> noreply()
  end

  @impl true
  def handle_event(
        "show_dropdown",
        %{"show" => show},
        %{assigns: %{index: index}} = socket
      ) do
    show = String.to_integer(show)
    show? = if show == index, do: false, else: show

    socket
    |> assign(index: show?)
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"cursor" => cursor, "direction" => direction},
        socket
      ) do
    update_fn =
      case direction do
        "back" -> &%{&1 | after: nil, before: cursor, first_index: &1.first_index - &1.limit}
        "forth" -> &%{&1 | after: cursor, before: nil, first_index: &1.first_index + &1.limit}
      end

    socket |> update(:pagination, update_fn) |> put_assigns() |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"per_page" => per_page},
        socket
      ) do
    limit = String.to_integer(per_page)

    socket
    |> assign(:pagination, %Pagination{limit: limit, last_index: limit})
    |> put_assigns()
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "open_compose",
        %{},
        %{assigns: %{index: index, jobs: jobs}} = socket
      ) do
    job = Enum.at(jobs, index)

    socket
    |> assign(:job, job)
    |> open_compose()
  end

  @impl true
  def handle_event(
        "delete_gallery_popup",
        %{"gallery_id" => gallery_id},
        socket
      ) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "delete_gallery",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Delete this gallery?",
      subtitle: "Are you sure you wish to permanently delete this gallery?"
    })
    |> assign(:gallery_id, gallery_id)
    |> noreply()
  end

  @impl true
  def handle_event("create_gallery", %{}, socket),
    do:
      socket
      |> open_modal(
        PicselloWeb.GalleryLive.CreateComponent,
        Map.take(socket.assigns, [:current_user])
      )
      |> noreply()

  def preview_icons(assigns) do
    standard_albums_count =
      assigns.albums
      |> Enum.filter(fn album -> album.is_proofing == false and album.is_finals == false end)
      |> Enum.count()

    proofing_albums_count =
      assigns.albums
      |> Enum.filter(fn album -> album.is_proofing == true end)
      |> Enum.count()

    final_albums_count =
      assigns.albums
      |> Enum.filter(fn album -> album.is_finals == true end)
      |> Enum.count()

    ~H"""
    <ul class="flex">
      <%= if Enum.any?(assigns.albums, fn album -> album.is_proofing == false and album.is_finals == false end) do %>
        <li class="cursor-pointer mr-1 custom-tooltip text-center">
          <span class="text-base-300"><%= standard_albums_count %> Standard album</span>
          <.icon name="standard_album" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
      <%= if Enum.any?(assigns.albums, & &1.is_proofing) do %>
        <li class="cursor-pointer mr-1 custom-tooltip">
        <span class="text-base-300"><%= proofing_albums_count %> Proofing album</span>
          <.icon name="proofing" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
      <%= if Enum.any?(assigns.albums, & &1.is_finals) do %>
        <li class="cursor-pointer custom-tooltip">
        <span class="text-base-300"><%= final_albums_count %> Proofing album</span>
          <.icon name="finals" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
    </ul>
    """
  end

  def image_item(assigns) do
    ~H"""
      <%= if Galleries.preview_image(@gallery) do %>
        <img class="rounded-lg float-left w-[180px] h-[119px] mr-4 md:w-[180px] md:h-[119px] md:mr-7" src={Galleries.preview_image(@gallery)}/>
      <% else %>
        <div class="rounded-lg float-left w-[180px] h-[119px] mr-4 md:w-[180px] md:h-[119px] md:mr-7 bg-base-200">
          <div class="flex justify-center mt-3">
            <.icon name="no-image-icon" class="inline-block w-9 h-9"/>
          </div>
          <div class="mt-1 text-base-250 font-normal text-center">
            <span>Edit your gallery to upload a cover photo</span>
          </div>
        </div>
      <% end %>
      <div class="py-0 md:py-2">
        <div class="font-bold">
          <%= Calendar.strftime(@gallery.inserted_at, "%m/%d/%y") %>
        </div>
        <div class="font-bold w-full">
          <%= live_redirect to: Routes.gallery_photographer_index_path(@socket, :index, @gallery.id) do %>
              <span class="w-full text-blue-planning-300 underline">
                <%= if String.length(@gallery |> Gallery.name()) < 30 do
                  @gallery |> Gallery.name()
                else
                  "#{@gallery |> Gallery.name() |> String.slice(0..29)} ..."
                end %>
              </span>
          <% end %>
        </div>
        <div class="text-base-250 font-normal ">
          <%= @gallery.albums |> Enum.count() %> albums
        </div>
        <%= if Enum.any?(@gallery.albums) do %>
          <div class="text-base-250 font-normal">
            <.preview_icons albums={@gallery.albums} />
          </div>
        <% end %>
      </div>
    """
  end

  def select(assigns) do
    ~H"""
    <div id="page-dropdown" class="flex items-center px-2 py-1 border rounded cursor-pointer border-blue-planning-300" phx-update="ignore" data-offset-y="10" phx-hook="Select">
      <div class="hidden border shadow popover-content">
        <%= for(option <- @options) do %>
          <label class={"p-2 pr-6 flex items-center cursor-pointer hover:bg-blue-planning-100 #{if @value == option, do: "bg-blue-planning-100", else: "bg-white"}"}>
            <input type="radio" class="hidden" name={@name} value={option} />
            <div class={"flex items-center justify-center w-5 h-5 mr-2 rounded-full #{if @value == option, do: "bg-blue-planning-300", else: "border"}"}>
              <.icon name="checkmark" class="w-3 h-3 stroke-current" />
            </div>
            <%= option %>
          </label>
        <% end %>
      </div>
      <span class="text-xs font-semibold"><%= @value %></span>
      <.icon name="down" class="w-3 h-3 ml-2 stroke-current stroke-2 open-icon text-blue-planning-300" />
      <.icon name="up" class="hidden w-3 h-3 ml-2 stroke-current stroke-2 close-icon text-blue-planning-300" />
    </div>
    """
  end

  defp open_compose(socket),
    do:
      socket
      |> PicselloWeb.ClientMessageComponent.open(%{
        modal_title: "Send an email",
        show_client_email: true,
        show_subject: true,
        presets: [],
        send_button: "Send"
      })
      |> noreply()

  defp get_jobs_list(galleries) do
    galleries
    |> Enum.reduce([], fn gallery, acc ->
      acc ++ [gallery.job]
    end)
  end

  defp put_assigns(
         %{assigns: %{current_user: current_user, live_action: action, pagination: pagination}} =
           socket
       ) do
    organization_id = Map.get(current_user, :organization).id

    galleries_query = Galleries.list_all_galleries_by_organization_query(organization_id)

    %{entries: galleries, metadata: metadata} =
      galleries_query
      |> Query.order_by(desc: :updated_at)
      |> Repo.paginate(
        pagination
        |> Map.take([:before, :after, :limit])
        |> Map.to_list()
        |> Enum.concat(cursor_fields: [updated_at: :desc])
      )

    jobs = get_jobs_list(galleries)

    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign(:galleries, galleries)
    |> assign(:jobs, jobs)
    |> assign(:index, false)
    |> assign(
      pagination: %{
        pagination
        | total_count: metadata.total_count,
          after: metadata.after,
          before: metadata.before,
          last_index: pagination.first_index + Enum.count(jobs) - 1
      }
    )
  end
end
