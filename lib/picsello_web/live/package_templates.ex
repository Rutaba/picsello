defmodule PicselloWeb.Live.PackageTemplates do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  import Picsello.Onboardings, only: [save_intro_state: 3]
  import PicselloWeb.PackageLive.Shared, only: [package_template_row: 1, current: 1]

  alias PicselloWeb.PaginationLive
  alias Ecto.Changeset

  alias Picsello.{
    Package,
    Packages,
    Repo,
    Profiles,
    PackagePaymentSchedule,
    Contract,
    Jobs,
    OrganizationJobType
  }

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign(
      page_title: "Settings",
      package_name: "All",
      show_on_public_profile: nil
    )
    |> is_mobile(params)
    |> assign_new(:pagination, fn -> PaginationLive.changeset() |> Changeset.apply_changes() end)
    |> assign_new(:pagination_changeset, fn -> PaginationLive.changeset() end)
    |> default_assigns()
    |> ok()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :new}} = socket),
    do:
      socket
      |> open_wizard()
      |> noreply()

  @impl true
  def handle_params(
        %{"id" => package_id},
        _,
        %{assigns: %{live_action: :edit, templates: templates}} = socket
      ) do
    package = Enum.find(templates, &(&1.id == to_integer(package_id)))

    if is_nil(package) do
      socket
      |> push_redirect(to: Routes.package_templates_path(socket, :index))
    else
      socket
      |> open_wizard(%{package: package |> Repo.preload([:contract, :package_payment_schedules])})
    end
    |> noreply()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :index}} = socket),
    do: socket |> noreply()

  @impl true
  def render(%{current_user: %{organization: %{id: org_id}}} = assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user} container_class="sm:pb-0 pb-28">
      <div class={classes("flex flex-col justify-between flex-1 mt-5 sm:flex-row", %{"flex-grow-0" => Enum.any?(@templates) })}>
        <div>
          <h1 class="text-2xl font-bold">Package Templates</h1>

          <p class="max-w-2xl my-2 text-base-250">
            Create reusable pricing and shoot templates to make it easier to manage leads. Looking to learn more about your pricing? <%= live_redirect to: Routes.calculator_path(@socket, :index), title: "Check out our helpful calculator!", class: "underline text-blue-planning-300 intro-calculator" do %>Check out our helpful calculator!<% end %>
          </p>
        </div>

        <div class="fixed bottom-0 left-0 right-0 z-20 flex flex-shrink-0 w-full p-6 mt-auto bg-white sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
          <button type="button" phx-click="add-package" class="w-full px-8 text-center btn-primary">Add package</button>
        </div>
      </div>

      <%= if show_intro?(@current_user, "intro_packages") === "true" do %>
        <.empty_state_base wrapper_class="border rounded-lg p-4 my-8" tour_embed="https://demo.arcade.software/41FJNpeq64KVC0pibQgu?embed" headline="Meet Packages" eyebrow_text="Packages Product Tour" body="Based on the info you gave us during onboarding, we’ve created default packages for you! Feel free to edit/archive or create your own." third_party_padding="calc(66.66666666666666% + 41px)" close_event="intro-close-packages">
          <button type="button" phx-click="add-package" class="w-full md:w-auto btn-tertiary flex-shrink-0 text-center">Add a package</button>
        </.empty_state_base>
      <% end %>

      <hr class="my-4" />
      <div class={classes("lg:mt-10", %{"hidden" => is_nil(@is_mobile)})}>
        <div class="flex flex-col lg:flex-row lg:mt-8">
          <div class={classes("lg:block", %{"hidden" => !@is_mobile})}>
            <div class="h-auto">
              <div phx-update="replace" class="w-full p-5 mt-auto sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto grid grid-cols-1 bg-base-200 rounded-xl lg:w-80 gap-y-1">
                <%= for(job_type <- @job_types) do %>
                  <div class={classes("font-bold bg-base-250/10 rounded-lg cursor-pointer grid-item", %{"text-blue-planning-300" => @package_name == job_type})} phx-click="assign_templates_by_job_type" phx-value-job-type={job_type}>
                    <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" >
                        <a class={"flex w-full #{job_type}-anchor-click"}>
                          <div class="flex items-center justify-start">
                            <div class="flex items-center justify-center flex-shrink-0 w-6 h-6 rounded-full bg-blue-planning-300">
                              <.icon name={job_type} class="w-3 h-3 m-1 fill-current text-white" />
                            </div>
                            <div class="justify-start ml-3">
                              <span class="capitalize"><%= job_type %> <span class="font-normal">(<%= @job_type_packages |> Map.get(job_type, [])|> Enum.count() %>)</span></span>
                            </div>
                          </div>
                          <div class="flex items-center px-2 ml-auto" phx-click="edit-job-type" phx-value-job-type-id={Jobs.get_job_type(job_type, org_id).id}>
                              <span class="text-blue-planning-300 link font-normal">Edit</span>
                          </div>
                        </a>
                    </div>
                    <%= if @package_name == job_type do %>
                      <span class="arrow show lg:block hidden">
                        <.icon name="arrow-filled" class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10" />
                      </span>
                    <% end %>
                  </div>
                <% end %>

                  <div class={classes("font-bold bg-base-250/10 rounded-lg cursor-pointer grid-item", %{"text-blue-planning-300" => @package_name == "All"})} phx-click="assign_all_templates">
                    <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" >
                        <a class="flex w-full">
                          <div class="flex items-center justify-start">
                            <div class="flex items-center justify-center flex-shrink-0 w-6 h-6 rounded-full bg-blue-planning-300">
                              <.icon name="archive" class="w-3 h-3 m-1 fill-current text-white" />
                            </div>
                            <div class="justify-start ml-3">
                              <span class="">All <span class="font-normal">(<%= @all_templates_count %>)</span></span>
                            </div>
                          </div>
                        </a>
                    </div>
                    <%= if @package_name == "All" do %>
                      <span class="arrow show lg:block hidden">
                        <.icon name="arrow-filled" class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10" />
                      </span>
                    <% end %>
                  </div>

                  <div class={classes("font-bold bg-base-250/10 rounded-lg cursor-pointer grid-item", %{"text-blue-planning-300" => @package_name == "Archived"})} phx-click="assign_archived_templates">
                    <div class="flex items-center lg:h-11 pr-4 lg:pl-2 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" >
                        <a class="flex w-full archived-anchor-click">
                          <div class="flex items-center justify-start">
                            <div class="flex items-center justify-center flex-shrink-0 w-6 h-6 rounded-full bg-blue-planning-300">
                              <.icon name="archive" class="w-3 h-3 m-1 fill-current text-white" />
                            </div>
                            <div class="justify-start ml-3">
                              <span class="">Archived <span class="font-normal">(<%= @archived_templates_count %>)</span></span>
                            </div>
                          </div>
                        </a>
                    </div>
                    <%= if @package_name == "Archived" do %>
                      <span class="arrow show lg:block hidden">
                        <.icon name="arrow-filled" class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10" />
                      </span>
                    <% end %>
                  </div>

                <div class="font-bold rounded-lg cursor-pointer grid-item" phx-click="edit-job-types">
                  <div class="flex items-center lg:h-11 pr-4 lg:pl-2 border border-blue-planning-300 lg:py-4 pl-3 py-3 overflow-hidden text-sm transition duration-300 ease-in-out rounded-lg text-ellipsis hover:text-blue-planning-300" >
                      <a class="flex w-full">
                        <div class="flex items-center justify-start">
                          <div class="flex items-center justify-center flex-shrink-0 w-6 h-6 rounded-full bg-blue-planning-300">
                            <.icon name="pencil" class="w-3 h-3 m-1 fill-current text-white" />
                          </div>

                          <div class="justify-start ml-3">
                            <span class="">Edit photography types</span>
                          </div>
                        </div>
                      </a>
                  </div>
                </div>
              </div>
            </div>
          </div>

        <div class={classes("w-full lg:p-0 lg:block", %{"hidden" => @is_mobile})}>
        <div class="flex-1 md:ml-8">
          <div class="flex items-center lg:mt-6">
            <div class="flex lg:hidden mr-1 w-8 h-8 items-center justify-center rounded-full bg-blue-planning-300" phx-click="back_to_navbar">
              <.icon name="back" class="stroke-current items-center ml-auto mr-auto w-5 h-5 text-white" />
            </div>
            <div class="pl-2 font-bold text-xl capitalize"><%= @package_name %> Packages</div>
              <%= if @package_name not in ["All", "Archived"] do%>
                <div class="flex custom-tooltip hover:cursor-pointer" phx-click="edit-job-type" phx-value-job-type-id={Jobs.get_job_type(@package_name, org_id).id}>
                  <%= if @show_on_public_profile do %>
                    <.icon name="eye" class={classes("inline-block w-5 h-5 ml-2 fill-current", %{"text-blue-planning-300" => @show_on_public_profile, "text-gray-400" => !@show_on_public_profile})} />
                  <% else %>
                    <.icon name="closed-eye" class={classes("inline-block w-5 h-5 ml-2 fill-current", %{"text-blue-planning-300" => @show_on_public_profile, "text-gray-400" => !@show_on_public_profile})} />
                  <% end %>
                  <span class="shadow-lg rounded-lg pb-2 px-2 text-xs capitalize"><%= @package_name %> Photography is <%= if @show_on_public_profile, do: "showing", else: "hidden" %> as an <br />offering on your public profile & contact form</span>
                </div>
              <% end %>
            </div>
            <%= if Enum.any? @templates do %>
              <div class="font-bold md:grid grid-cols-6 mt-2 hidden md:inline-block">
                <%= for title <- ["Package Details", "Pricing", "Actions"] do %>
                  <div class="col-span-2 pl-2"><%= title %></div>
                <% end %>
              </div>

              <hr class="my-8 border-blue-planning-300 border-2 mt-4 mb-1 hidden md:block" />

              <div class="my-4 flex flex-col">
                <%= for template <- @templates do %>
                  <.package_template_row update_mode="replace" package={template} class="h-full"/>
                <% end %>
              </div>
              <%= if @pagination.total_count > 4 do %>
                <div class="flex items-center px-6 pb-6 center-container">
                  <.form let={f} for={@pagination_changeset} phx-change="page" class="flex items-center text-gray-500 rounded p-1 border cursor-pointer border-blue-planning-300">
                    <%= select f, :limit, [4, 8, 12, 16], class: "cursor-pointer"%>
                  </.form>

                  <div class="flex ml-2 text-xs font-bold text-gray-500">
                    Results: <%= @pagination.first_index %> – <%= if @pagination.last_index > @pagination.total_count, do: @pagination.total_count, else: @pagination.last_index %> of <%= @pagination.total_count %>
                  </div>

                  <div class="flex items-center ml-auto">
                    <button class="flex items-center p-4 text-xs font-bold rounded disabled:text-gray-300 hover:bg-gray-100" title="Previous page" phx-click="page" phx-value-direction="back" disabled={@pagination.first_index == 1}>
                      <.icon name="back" class="w-3 h-3 mr-1 stroke-current stroke-2" />
                      Prev
                    </button>
                    <button class="flex items-center p-4 text-xs font-bold rounded disabled:text-gray-300 hover:bg-gray-100" title="Next page" phx-click="page" phx-value-direction="forth"  disabled={@pagination.last_index >= @pagination.total_count}>
                      Next
                      <.icon name="forth" class="w-3 h-3 ml-1 stroke-current stroke-2" />
                    </button>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div class="flex flex-col md:flex-row lg:mt-2 mt-6">
                <img src="/images/empty-state.png" />
                <div class="lg:ml-10 flex flex-col justify-center mt-6 lg:mt-0 ml-0">
                  <div class="font-bold">
                    Missing packages
                  </div>
                  <div class="font-normal lg:w-72 text-base-250">
                    You don't have any packages! Click add a package to get started. If you need help, check out <a target="_blank" class="underline text-blue-planning-300" href="https://support.picsello.com/article/34-create-a-package-template">this guide</a>!
                  </div>
                </div>
              </div>
            <% end %>
            </div>
            </div>
          </div>
        </div>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket
    |> assign(:is_mobile, !is_mobile)
    |> assign_new(:pagination, fn -> PaginationLive.changeset() |> Changeset.apply_changes() end)
    |> assign_new(:pagination_changeset, fn -> PaginationLive.changeset() end)
    |> default_assigns()
    |> noreply
  end

  @impl true
  def handle_event(
        "page",
        %{"direction" => direction},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    updated_pagination =
      case direction do
        "back" ->
          pagination
          |> PaginationLive.changeset(%{
            first_index: pagination.first_index - pagination.limit,
            offset: pagination.offset - pagination.limit
          })
          |> Changeset.apply_changes()

        "forth" ->
          pagination
          |> PaginationLive.changeset(%{
            first_index: pagination.first_index + pagination.limit,
            offset: pagination.offset + pagination.limit
          })
          |> Changeset.apply_changes()
      end

    socket
    |> assign(:pagination, updated_pagination)
    |> assign_templates()
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"pagination_live" => %{"limit" => limit}},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    limit = to_integer(limit)

    updated_pagination_changeset =
      pagination
      |> PaginationLive.changeset(%{limit: limit, last_index: limit, first_index: 1, offset: 0})

    socket
    |> assign(:pagination_changeset, updated_pagination_changeset)
    |> assign(:pagination, updated_pagination_changeset |> Changeset.apply_changes())
    |> assign_templates()
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event("add-package", %{}, socket),
    do:
      socket
      # |> assign_job_types()
      |> push_patch(to: Routes.package_templates_path(socket, :new))
      |> noreply()

  @impl true
  def handle_event(
        "edit-package",
        %{"package-id" => package_id},
        socket
      ),
      do:
        socket
        # |> assign_job_types()
        |> push_patch(to: Routes.package_templates_path(socket, :edit, package_id))
        |> noreply()

  @impl true
  def handle_event("toggle-archive", %{"package-id" => package_id, "type" => type}, socket),
    do:
      socket
      |> assign(:archive_package_id, package_id)
      |> PicselloWeb.ConfirmationComponent.open(%{
        close_label: "No! Get me out of here",
        confirm_event: "archive_unarchive",
        confirm_label: if(type == "archive", do: "Yes, archive", else: "Yes, unarchive"),
        icon: "warning-orange",
        subtitle:
          if(type == "archive", do: "Archiving", else: "Un-archiving") <>
            " a package template doesn’t affect active leads or jobs—this will just " <>
            if(type == "archive", do: "remove", else: "add back") <>
            " the option to create anything with this package template.",
        title:
          "Are you sure you want to " <>
            if(type == "archive", do: "archive", else: "Un-archive") <> " this package template?"
      })
      |> noreply()

  @impl true
  def handle_event(
        "intro-close-packages",
        _,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: save_intro_state(current_user, "intro_packages", :dismissed))
    |> noreply()
  end

  @impl true
  def handle_event(
        "duplicate-package",
        %{"package-id" => package_id},
        socket
      ) do
    package =
      Repo.get(Package, package_id)
      |> Repo.preload([
        :organization,
        :job,
        :contract,
        :package_template,
        :package_payment_schedules,
        :questionnaire_template
      ])

    duplicate_package_attrs = create_duplicate_package(package)

    case Repo.insert(duplicate_package_attrs) do
      {:ok, _duplicated_package} ->
        socket
        |> put_flash(:success, "The package: #{package.name} has been duplicated")
        |> close_modal()

      _ ->
        socket
        |> put_flash(:error, "Failed to duplicate package: #{package.name}")
    end
    |> assign_template_counts()
    |> assign_templates()
    |> assign_job_type_packages()
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-visibility-confirmation",
        %{"package-id" => package_id},
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    url = Profiles.public_url(organization)
    package = Repo.get!(Package, package_id)

    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "Cancel",
      confirm_event: "toggle_package_visibility",
      confirm_class: if(package.show_on_public_profile, do: "btn-warning", else: "btn-primary"),
      confirm_label:
        if(package.show_on_public_profile, do: "Hide", else: "Great! Show") <>
          " on my Public Profile",
      opened_for: if(package.show_on_public_profile, do: "hidden-modal", else: "show-modal"),
      icon: "no-icon",
      external_link:
        if(package.show_on_public_profile,
          do: "What’s my Public Profile?",
          else: "Open client-facing Public Profile in new tab"
        ),
      url: url,
      subtitle:
        if(package.show_on_public_profile,
          do:
            "Don’t worry! You aren’t deleting or archiving your package. You’re just hiding it from potential clients on your Public Profile.",
          else:
            "You also have access to a Public Profile where you can book clients, share your contact form, and showcase some of your packages and pricing to get you booked!"
        ),
      title:
        if(package.show_on_public_profile, do: "Hide", else: "Show") <> " on your Public Profile?",
      payload: %{
        package_id: package_id,
        is_hidden: if(package.show_on_public_profile, do: true, else: false)
      }
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "assign_all_templates",
        _,
        socket
      ) do
    socket
    |> assign(package_name: "All")
    |> assign(is_mobile: false)
    |> reassign_templates()
    |> noreply()
  end

  @impl true
  def handle_event(
        "assign_templates_by_job_type",
        %{"job-type" => job_type},
        %{assigns: %{current_user: %{organization: %{id: organization_id}}}} = socket
      ) do
    socket
    |> assign(
      package_name: job_type,
      is_mobile: false,
      show_on_public_profile: refresh_visbility(job_type, organization_id)
    )
    |> reassign_templates()
    |> noreply()
  end

  @impl true
  def handle_event(
        "assign_archived_templates",
        _,
        socket
      ) do
    socket
    |> assign(package_name: "Archived")
    |> assign(is_mobile: false)
    |> reassign_templates()
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-job-types",
        %{},
        socket
      ) do
    socket
    |> assign_job_types()
    |> PicselloWeb.PackageLive.EditJobTypeComponent.open()
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.PackageLive.Shared

  @impl true
  def handle_info(
        {:confirm_event, "next", %{changeset: changeset} = payload,
         %{"check" => %{"check_enabled" => check_enabled} = params}},
        %{
          assigns: %{
            current_user: %{organization_id: organization_id},
            package_name: package_name
          }
        } = socket
      ) do
    check_enabled = check_enabled |> String.to_atom()

    changeset =
      changeset
      |> Changeset.put_change(:show_on_business?, check_enabled)
      |> Changeset.put_change(
        :show_on_profile?,
        String.to_atom(Map.get(params, "check_profile", "false"))
      )

    if changeset |> Changeset.get_change(:show_on_business?) do
      job_type = changeset |> current() |> Map.get(:job_type)
      packages_exist? = Packages.packages_exist?(job_type, organization_id)

      params = %{
        confirm_event: "save",
        close_event: "no-packages",
        confirm_label:
          "Yes, #{if packages_exist?, do: "unarchive old", else: "create default"} packages",
        close_label: "No, I will make #{if packages_exist?, do: "new packages", else: "my own"}",
        confirm_class: "btn-primary",
        icon: job_type,
        heading: if(packages_exist?, do: "DO YOU REMEMBER?", else: "DID YOU KNOW?"),
        subtitle:
          if(packages_exist?,
            do:
              "You created some packages earlier when this type was enabled, You could unarchive those packages now and use them as a starting point or just take a look. You can always archive them again at any time and don't worry, they won't be displayed on your public profile unless you set them to be displayed!",
            else:
              "We have default packages that are built using our pricing calculator which references your location, time in the industry, and whether your are part-time or full-time. You can always archive them or use as a starting point!"
          ),
        title:
          "#{if packages_exist?, do: "Unarchive existing", else: "Create default"} packages?",
        payload: payload |> Map.replace(:changeset, changeset)
      }

      socket
      |> PicselloWeb.PackageLive.ConfirmationComponent.open(params)
    else
      socket
      |> toggle_job_type_for_profile(changeset)
      |> close_modal()
    end
    |> assign(
      :show_on_public_profile,
      if(package_name not in ["All", "Archived"],
        do: Jobs.get_job_type(package_name, organization_id).show_on_profile
      )
    )
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "next", %{changeset: changeset},
         %{"check" => %{"check_profile" => check_profile}}},
        socket
      ) do
    changeset =
      changeset
      |> Changeset.put_change(:show_on_profile?, String.to_atom(check_profile))

    socket
    |> toggle_job_type_for_profile(changeset)
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "save", %{changeset: changeset}, _},
        socket
      ) do
    case Repo.update(changeset) do
      {:ok, org_job_type} ->
        create_or_unarchive_packages(org_job_type, socket)

      {:error, _} ->
        socket
        |> put_flash(:success, "The type has been enabled alongwith its associated packages")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:close_event, "no-packages", %{changeset: changeset}, _},
        socket
      ) do
    case Repo.update(changeset) do
      {:ok, _org_job_type} ->
        socket
        |> default_assigns()
        |> put_flash(:success, "The type has been enabled without any packages")

      {:error, _} ->
        socket
        |> put_flash(:error, "The type could not be enabled, please try again.")
    end
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "visibility_for_business",
         %{organization_job_type: %{id: job_type_id}} = payload, _params},
        %{
          assigns: %{
            current_user: %{organization: %{organization_job_types: org_job_types, id: org_id}}
          }
        } = socket
      ) do
    org_job_type =
      org_job_types
      |> Enum.find(fn job_type -> job_type.id == to_integer(job_type_id) end)

    if org_job_type.show_on_business? do
      socket
      |> PicselloWeb.PackageLive.ConfirmationComponent.open(%{
        close_label: "Cancel",
        confirm_event: "disable_job_type_for_business",
        confirm_label: "Yes, disable",
        icon: org_job_type.job_type,
        subtitle:
          "You are disabling this photography type for your business. You will not be able to select it when creating a job, gallery, or lead. We will also hide it on your Public Profile.",
        subtitle2:
          "Your packages will remain intact in case you enable this photography type again in the future.",
        title: "Are you sure?",
        payload: payload
      })
    else
      socket
      |> assign(
        :show_on_public_profile,
        Jobs.get_job_type(org_job_type, org_id).show_on_profile
      )
    end
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "disable_job_type_for_business", %{changeset: changeset}, _params},
        %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
      ) do
    changeset =
      changeset
      |> Changeset.put_change(:show_on_business?, false)
      |> Changeset.put_change(:show_on_profile?, false)

    {:ok, org_job_type} = Repo.update(changeset)

    case Packages.archive_packages_for_job_type(org_job_type.job_type, organization_id) do
      {_row_count, nil} ->
        socket
        |> assign(:package_name, "All")
        |> default_assigns()
        |> close_modal()

      _ ->
        socket
    end
    |> put_flash(:success, "The type has been disabled, alongwith its associated packages")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "toggle_package_visibility",
         %{package_id: package_id, is_hidden: is_hidden}},
        socket
      ) do
    with %Package{} = package <- Repo.get(Package, package_id),
         {:ok, _package} <- package |> Package.edit_visibility_changeset() |> Repo.update() do
      socket
      |> put_flash(
        :success,
        "The package has been " <> if(is_hidden, do: "hidden", else: "shown")
      )
      |> close_modal()
    else
      _ ->
        socket
        |> put_flash(:error, "Failed to show/hide package")
    end
    |> assign_job_type_packages()
    |> assign_templates()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "archive_unarchive"},
        %{assigns: %{current_user: current_user, archive_package_id: package_id}} = socket
      ) do
    with %Package{} = package <- Repo.get(Package, package_id),
         {:ok, _package} <- archive_unarchive_package(current_user, package) do
      socket
      |> default_assigns()
      |> put_flash(
        :success,
        "The package has been " <> if(package.archived_at, do: "un-archived", else: "archived")
      )
      |> close_modal()
    else
      _ ->
        socket
        |> put_flash(:error, "Failed to archive package")
    end
    |> noreply()
  end

  @impl true
  def handle_info({:update, _package}, socket) do
    socket
    |> assign_templates()
    |> assign_job_type_packages()
    |> assign_template_counts()
    |> put_flash(:success, "The package has been successfully saved")
    |> noreply()
  end

  @impl true
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> push_patch(to: Routes.package_templates_path(socket, :index))
    |> noreply()
  end

  defp default_assigns(socket) do
    socket
    |> assign_job_types()
    |> assign_job_type_packages()
    |> assign_templates()
    |> assign_template_counts()
  end

  defp archive_unarchive_package(%{organization: organization}, package) do
    if is_nil(package.archived_at) do
      package |> Package.archive_changeset() |> Repo.update()
    else
      organization_job_type =
        organization.organization_job_types
        |> Enum.find(fn row ->
          row.job_type == package.job_type && row.organization_id == organization.id
        end)

      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :organization_job_type,
        OrganizationJobType.update_changeset(organization_job_type, %{show_on_business?: true})
      )
      |> Ecto.Multi.update(:package, Ecto.Changeset.change(package, archived_at: nil))
      |> Repo.transaction()
    end
  end

  defp assign_templates(
         %{assigns: %{current_user: %{organization_id: organization_id}, package_name: "All"}} =
           socket
       ),
       do:
         Package.templates_for_organization_query(organization_id)
         |> assign_templates_and_pagination(socket)

  defp assign_templates(
         %{
           assigns: %{current_user: %{organization_id: organization_id}, package_name: "Archived"}
         } = socket
       ),
       do:
         Package.archived_templates_for_organization(organization_id)
         |> assign_templates_and_pagination(socket)

  defp assign_templates(%{assigns: %{current_user: user, package_name: package_name}} = socket),
    do:
      Package.templates_for_user(user, package_name)
      |> assign_templates_and_pagination(socket)

  defp reassign_templates(
         %{assigns: %{current_user: %{organization_id: organization_id}, package_name: "All"}} =
           socket
       ),
       do:
         Package.templates_for_organization_query(organization_id)
         |> reassign_templates_and_pagination(socket)

  defp reassign_templates(
         %{
           assigns: %{current_user: %{organization_id: organization_id}, package_name: "Archived"}
         } = socket
       ),
       do:
         Package.archived_templates_for_organization(organization_id)
         |> reassign_templates_and_pagination(socket)

  defp reassign_templates(%{assigns: %{current_user: user, package_name: package_name}} = socket),
    do:
      Package.templates_for_user(user, package_name)
      |> reassign_templates_and_pagination(socket)

  defp assign_templates_and_pagination(query, socket) do
    updated_pagination = update_pagination(query, socket)
    templates = Packages.paginate_query(query, updated_pagination) |> Repo.all()

    socket
    |> assign(
      templates: templates,
      pagination: updated_pagination
    )
  end

  defp reassign_templates_and_pagination(query, socket) do
    reset_pagination = reset_pagination(query, socket)
    templates = Packages.paginate_query(query, reset_pagination) |> Repo.all()

    socket
    |> assign(
      templates: templates,
      pagination: reset_pagination
    )
  end

  defp update_pagination(query, %{
         assigns: %{
           pagination: %{offset: offset, limit: limit} = pagination
         }
       }) do
    updated_total_count = template_count_by_query(query)
    updated_last_index = offset + 1 * limit

    if offset == updated_total_count && updated_total_count > 0 do
      pagination
      |> PaginationLive.changeset(%{
        total_count: updated_total_count,
        first_index: updated_total_count - limit,
        last_index: updated_total_count,
        offset: offset - limit
      })
      |> Changeset.apply_changes()
    else
      pagination
      |> PaginationLive.changeset(%{
        total_count: updated_total_count,
        last_index: updated_last_index
      })
      |> Changeset.apply_changes()
    end
  end

  defp reset_pagination(query, %{assigns: %{pagination: pagination}}) do
    pagination
    |> PaginationLive.changeset(%{
      limit: pagination.limit,
      offset: 0,
      first_index: 1,
      last_index: pagination.limit,
      total_count: template_count_by_query(query)
    })
    |> Changeset.apply_changes()
  end

  defp template_count_by_query(query),
    do:
      query
      |> Repo.all()
      |> Enum.count()

  defp assign_job_type_packages(
         %{
           assigns: %{
             current_user: %{organization_id: organization_id},
             job_types: job_types
           }
         } = socket
       ) do
    {packages, _} =
      Package.templates_for_organization_query(organization_id)
      |> Repo.all()
      |> Enum.group_by(& &1.job_type)
      |> Map.split(job_types)

    socket |> assign(:job_type_packages, packages)
  end

  defp open_wizard(socket, assigns \\ %{}) do
    socket
    |> open_modal(PicselloWeb.PackageLive.WizardComponent, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user]))
    })
  end

  defp assign_template_counts(
         %{assigns: %{current_user: %{organization: %{id: org_id}}}} = socket
       ) do
    socket
    |> assign(
      archived_templates_count:
        Package.archived_templates_for_organization(org_id) |> Repo.all() |> Enum.count(),
      all_templates_count:
        Package.all_templates_for_organization(org_id) |> Repo.all() |> Enum.count()
    )
  end

  defp assign_job_types(%{assigns: %{current_user: current_user}} = socket) do
    current_user =
      current_user |> Repo.preload([organization: :organization_job_types], force: true)

    socket
    |> assign(:current_user, current_user)
    |> assign(
      :job_types,
      Profiles.enabled_job_types(current_user.organization.organization_job_types)
    )
  end

  defp create_duplicate_package(package) do
    timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    package_payment_schedules =
      if Enum.any?(package.package_payment_schedules),
        do:
          Enum.map(package.package_payment_schedules, fn payment_schedule ->
            payment_schedule
            |> create_attrs_from_struct(timestamp)
            |> then(fn params ->
              PackagePaymentSchedule.changeset_for_duplication(%PackagePaymentSchedule{}, params)
            end)
            |> Ecto.Changeset.apply_changes()
          end),
        else: []

    contract =
      if is_map(package.contract) do
        package.contract
        |> create_attrs_from_struct(timestamp)
        |> Contract.changeset()
        |> Ecto.Changeset.apply_changes()
      else
        %{}
      end

    case contract do
      %Contract{} ->
        package
        |> Map.replace(:contract, contract)

      _ ->
        package
    end
    |> Map.merge(%{
      id: nil,
      name: "Duplicate - #{package.name}",
      package_payment_schedules: package_payment_schedules,
      inserted_at: timestamp,
      updated_at: timestamp
    })
    |> Repo.preload([:questionnaire_template])
  end

  defp refresh_visbility(job_type, organization_id) do
    Jobs.get_all_job_types(organization_id)
    |> Enum.filter(fn type ->
      type.job_type == job_type
    end)
    |> List.first()
    |> Map.get(:show_on_profile?)
  end

  defp toggle_job_type_for_profile(socket, changeset) do
    case Repo.update(changeset) do
      {:ok, org_job_type} ->
        socket
        |> default_assigns()
        |> put_flash(
          :success,
          "The type #{if org_job_type.show_on_profile?, do: "will now be displayed on", else: "has been hidden from"} your public profile"
        )

      {:error, _} ->
        socket
        |> put_flash(:error, "The action could not be completed successfully, please try again.")
    end
  end

  defp create_attrs_from_struct(struct, date) do
    struct
    |> Map.from_struct()
    |> Map.delete([:__struct__, :__meta__, :id])
    |> Map.merge(%{inserted_at: date, updated_at: date})
  end

  defp create_or_unarchive_packages(
         %{job_type: job_type},
         %{
           assigns: %{
             current_user: %{organization_id: organization_id} = user
           }
         } = socket
       ) do
    if Packages.packages_exist?(job_type, organization_id) do
      case Packages.unarchive_packages_for_job_type(job_type, organization_id) do
        {_row_count, nil} ->
          socket
          |> default_assigns()
          |> put_flash(:success, "The type has been enabled alongwith its associated packages")

        _ ->
          socket
          |> put_flash(:error, "Failed to enable the job type")
      end
    else
      Packages.create_initial(user, job_type)

      socket
      |> default_assigns()
      |> put_flash(:success, "The type has been enabled alongwith its default packages")
    end
  end

  defdelegate job_types(), to: Picsello.Profiles
end
