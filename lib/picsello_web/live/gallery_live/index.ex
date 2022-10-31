defmodule PicselloWeb.GalleryLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

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
    |> update_gallery_listing()
    |> ok()
  end

  @impl true
  def handle_event(
        "show_dropdown",
        %{"show_index" => show_index},
        %{assigns: %{index: index}} = socket
      ) do
    show_index = String.to_integer(show_index)
    show? = if show_index == index, do: false, else: show_index

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

    socket
    |> update(:pagination, update_fn)
    |> pagination()
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"pagination" => %{"limit" => limit}},
        socket
      ) do
    limit = String.to_integer(limit)

    socket
    |> assign(:pagination, %Pagination{limit: limit, last_index: limit})
    |> pagination()
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
    {:ok, _} = String.to_integer(gallery_id) |> Galleries.delete_gallery_by_id()

    socket
    |> update_gallery_listing()
    |> close_modal()
    |> put_flash(:success, "Gallery deleted successfully")
    |> noreply()
  end

  @impl true
  def handle_info({:gallery_created, %{job_id: job_id}}, socket) do
    socket
    |> PicselloWeb.SuccessComponent.open(%{
      title: "Gallery Created!",
      subtitle: "Hooray! Your gallery has been created. you are now ready to upload photos.",
      success_label: "View new job",
      success_event: "view-job",
      close_label: "Great! Close window.",
      payload: %{job_id: job_id}
    })
    |> update_gallery_listing()
    |> noreply()
  end

  def preview_icons(assigns) do
    standard_albums_count =
      assigns.albums
      |> Enum.filter(&(&1.is_proofing == false and &1.is_finals == false))
      |> Enum.count()

    proofing_albums_count =
      assigns.albums
      |> Enum.filter(&(&1.is_proofing == true and &1.is_finals == false))
      |> Enum.count()

    final_albums_count =
      assigns.albums
      |> Enum.filter(&(&1.is_finals == true))
      |> Enum.count()

    ~H"""
    <ul class="flex">
      <%= if Enum.any?(assigns.albums, fn album -> album.is_proofing == false and album.is_finals == false end) do %>
        <li class="cursor-pointer mr-1 custom-tooltip text-center">
          <span class="text-base-300"><%= standard_albums_count %> Standard <%= ngettext("album", "albums", standard_albums_count)%></span>
          <.icon name="standard_album" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
      <%= if Enum.any?(assigns.albums, & &1.is_proofing) do %>
        <li class="cursor-pointer mr-1 custom-tooltip">
          <span class="text-base-300"><%= proofing_albums_count %> Proofing <%= ngettext("album", "albums", proofing_albums_count)%></span>
          <.icon name="proofing" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
      <%= if Enum.any?(assigns.albums, & &1.is_finals) do %>
        <li class="cursor-pointer custom-tooltip">
          <span class="text-base-300"><%= final_albums_count %> Finals <%= ngettext("album", "albums", final_albums_count)%></span>
          <.icon name="finals" class="inline-block w-4 h-4"/>
        </li>
      <% end %>
    </ul>
    """
  end

  def image_item(assigns) do
    ~H"""
      <div class="flex flex-col md:flex-row">
        <%= if Galleries.preview_image(@gallery) do %>
          <div class="rounded-lg float-left w-[200px] mr-4 md:mr-7 min-h-[130px]" style={"background-image: url('#{Galleries.preview_image(@gallery)}'); background-repeat: no-repeat; background-size: cover; background-position: center;"}>
          </div>
        <% else %>
          <div class="rounded-lg h-full p-4 items-center flex flex-col w-[200px] h-[130px] mr-4 md:mr-7 bg-base-200">
            <div class="flex justify-center h-full items-center">
              <.icon name="photos-2" class="inline-block w-9 h-9 text-base-250"/>
            </div>
            <div class="mt-1 text-base-250 text-center h-full">
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
                  <%= if String.length(@gallery.name) < 30 do
                    @gallery.name
                  else
                    "#{@gallery.name |> String.slice(0..29)} ..."
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

  def pagination(%{assigns: assigns} = socket) do
    assigns = Map.put_new(assigns, :pagination, %Pagination{})
    put_assigns(socket, assigns)
  end

  def update_gallery_listing(%{assigns: assigns} = socket) do
    assigns = Map.put(assigns, :pagination, %Pagination{})
    put_assigns(socket, assigns)
  end

  def put_assigns(socket, %{current_user: current_user} = assigns) do
    pagination = Map.get(assigns, :pagination)
    action = Map.get(assigns, :live_action)
    organization_id = Map.get(current_user, :organization).id

    %{entries: galleries, metadata: metadata} =
      Galleries.list_all_galleries_by_organization_query(organization_id)
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
