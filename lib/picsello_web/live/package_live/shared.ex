defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  use Phoenix.HTML
  use Phoenix.Component

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  import PicselloWeb.FormHelpers
  import PicselloWeb.LiveHelpers
  import Phoenix.HTML.Form
  import PicselloWeb.Gettext

  alias Picsello.{Package, BrandLink, OrganizationJobType}

  def update(%{current_user: %{organization: organization}} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_brand_links()
    |> assign_changeset(%{organization_id: organization.id})
    |> ok()
  end

  def open(%{assigns: assigns} = socket, module),
    do:
      open_modal(
        socket,
        module,
        %{assigns: assigns |> Map.drop([:flash])}
      )

  defp assign_brand_links(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    organization =
      case organization do
        %{brand_links: []} = organization ->
          Map.put(organization, :brand_links, [
            %BrandLink{
              title: "Website",
              link_id: "website",
              organization_id: organization.id
            }
          ])

        organization ->
          organization
      end

    socket
    |> assign(:organization, organization)
  end

  def assign_changeset(
        socket,
        params \\ %{},
        action \\ :validate
      ),
      do:
        assign(socket,
          changeset: OrganizationJobType.update_changeset(params) |> Map.put(:action, action)
        )

  def handle_event(
        "edit-job-type",
        %{"job-type-id" => id},
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    org_job_type =
      organization.organization_job_types
      |> Enum.find(fn job_type -> job_type.id == to_integer(id) end)

    changeset = OrganizationJobType.update_changeset(org_job_type, %{})

    params = %{
      checkbox_event: "visibility_for_business",
      checkbox_event2: "visibility_for_profile",
      checked: org_job_type.show_on_business?,
      checked2: org_job_type.show_on_profile?,
      confirm_event: "next",
      confirm_label: "Save",
      confirm_class: "btn-primary",
      icon: org_job_type.job_type,
      heading2: "Show photography type on your public profile and contact form?",
      subtitle2: "Will only show if your Public Profile is enabled",
      title: "Edit Photography Type",
      payload: %{changeset: changeset, organization_job_type: org_job_type}
    }

    params =
      if org_job_type.job_type != "other",
        do:
          params
          |> Map.put(:heading, "Enable this for my business")
          |> Map.put(
            :subtitle,
            "I would like to be able to select this when creating leads, jobs, and galleries"
          ),
        else: params

    socket
    |> PicselloWeb.PackageLive.ConfirmationComponent.open(params)
    |> noreply()
  end

  @spec package_card(%{
          package: %Package{}
        }) :: %Phoenix.LiveView.Rendered{}
  def package_card(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: ""
      })

    assigns = assign_new(assigns, :is_edit, fn -> true end)

    ~H"""
    <div class={"flex flex-col p-4 border rounded cursor-pointer hover:bg-blue-planning-100 hover:border-blue-planning-300 group #{@class}"}>
      <h1 class="text-2xl font-bold line-clamp-2"><%= @package.name %></h1>

      <div class="mb-4 relative" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="mouseover">
        <div class="line-clamp-2 raw_html raw_html_inline">
          <%= raw @package.description %>
        </div>
        <div class="hidden p-4 text-sm rounded bg-white font-sans shadow my-4 w-full absolute top-2 z-[15]" data-offset="0" role="tooltip">
          <div class="line-clamp-6 raw_html"></div>
          <button class="inline-block text-blue-planning-300">View all</button>
        </div>
        <%= if package_description_length_long?(@package.description) do %>
          <button class="inline-block text-blue-planning-300 view_more">View more</button>
        <% end %>
      </div>

      <dl class="flex flex-row-reverse items-center justify-end mt-auto">
        <.digital_detail id="package_detail" download_each_price={@package.download_each_price} download_count={@package.download_count}/>
      </dl>

      <hr class="my-4" />

      <div class="flex items-center justify-between">
        <div class="text-gray-500"><%= dyn_gettext @package.job_type %></div>

        <div class="text-lg font-bold">
          <%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %>
        </div>
      </div>

      <div class="flex items-center justify-between">
        <div class="text-gray-500">Download Price</div>

        <div class="text-lg font-bold">
          <%= if Money.zero?(@package.download_each_price) do %>--<% else %><%= @package.download_each_price %>/each<% end %>
        </div>
      </div>

    </div>
    """
  end

  @spec package_template_row(%{package: %Package{}}) :: %Phoenix.LiveView.Rendered{}
  def package_template_row(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        update_mode: "ignore"
      })

    ~H"""
    <div class="border border-solid rounded p-4 mb-3 ml-0 md:p-0 md:mb-0 md:ml-2 md:border-0">
      <div class="relative" {testid("package-template-card")}>
        <div class="flex items-center">
          <%= if @package.archived_at do %>
            <h1 title={@package.name} class="text-xl font-bold line-clamp-2 text-blue-planning-300">
              <%= truncate_package_name(@package.name) %>
            </h1>
            <% else %>
            <h1 title={@package.name} phx-click="edit-package" phx-value-package-id={@package.id} class="text-xl font-bold line-clamp-2 text-blue-planning-300 link hover:cursor-pointer">
              <%= truncate_package_name(@package.name) %>
            </h1>
            <div class="flex items-center custom-tooltip" phx-click="edit-visibility-confirmation" phx-value-package-id={@package.id}>
              <.icon name={if @package.show_on_public_profile, do: "eye", else: "closed-eye"} class={classes("w-5 h-5 mx-2 hover:cursor-pointer", %{"text-gray-400" => !@package.show_on_public_profile, "text-blue-planning-300" => @package.show_on_public_profile})}/>
              <span class="shadow-lg rounded-lg py-1 px-2 text-xs">
                <%= if @package.show_on_public_profile, do: 'Shown on your Public Profile', else: 'Hidden on your Public Profile' %>
              </span>
            </div>
          <% end %>
        </div>
        <div class="grid grid-cols-1 grid-cols-1 md:grid-cols-6 gap-4">
          <div class={"flex flex-col md:col-span-2 group #{@class}"}>
            <div class="md:mb-4 relative" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="mouseover">
              <div class="line-clamp-2 raw_html raw_html_inline text-base-250">
                <%= raw @package.description %>
              </div>
              <%= if package_description_length_long?(@package.description) do %>
                <button class="inline-block text-blue-planning-300 view_more">View more</button>
              <% end %>
              <div class="hidden md:block md:flex items-center md:my-2">
                <span class="line-clamp-2 w-5 h-5 mr-2 flex items-center justify-center text-xs font-bold rounded-full bg-gray-200 text-center">
                  <%= @package.download_count %>
                </span>
                <span class="text-base-250">Downloadable photos</span>
              </div>
              <span class="hidden md:inline justify-start text-xs bg-gray-200 text-gray-800 px-2 py-1 rounded"><%= String.capitalize(@package.job_type) %></span>
              <div class="hidden p-4 text-sm rounded bg-white font-sans shadow my-4 w-full absolute top-2 z-[15]" data-offset="0" role="tooltip">
                <div class="line-clamp-6 raw_html"></div>
                <%= if !@package.archived_at do %>
                  <button class="inline-block text-blue-planning-300" phx-click="edit-package" phx-value-package-id={@package.id}>View all</button>
                <% end %>
              </div>
            </div>
          </div>

          <div class="md:col-span-2">
            <div class="flex items-center text-base-250">
              <span class="">Package price:&nbsp;</span>
              <div class="">
                <%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %>
              </div>
            </div>
            <div class="flex items-center text-base-250">
              <div class="">Digital image price:&nbsp;</div>
              <div class="">
                <%= if Money.zero?(@package.download_each_price) do %>--<% else %><%= @package.download_each_price %>/each<% end %>
              </div>
            </div>
          </div>

          <div class="block md:hidden flex items-center">
            <span class="line-clamp-2 w-5 h-5 mr-2 flex items-center justify-center text-xs font-bold rounded-full bg-gray-200 text-center">
              <%= @package.download_count %>
            </span>
            <span class="text-base-250">Downloadable photos</span>
          </div>

          <div class="inline md:hidden justify-start">
            <span class="text-xs bg-gray-200 text-gray-800 px-2 py-1 rounded"><%= String.capitalize(@package.job_type) %></span>
          </div>

          <div class="md:col-span-2 md:ml-auto">
            <%= if !@package.archived_at do %>
              <hr class="my-4 block md:hidden" />
            <% end %>
            <div class="flex items-center flex-wrap gap-4">
                <%= if !@package.archived_at do %>
                  <.icon_button {testid("edit-package-#{@package.id}")} class="btn-tertiary text-white bg-blue-planning-300 hover:bg-blue-planning-300/75 hover:opacity-75 transition-colors text-white flex-shrink-0 grow md:grow-0 text-center justify-center" title="edit link" phx-click="edit-package" phx-value-package-id={@package.id} color="white" icon="pencil">
                    Edit package
                  </.icon_button>
                <% end %>
                <div class="grow md:grow-0 md:ml-2" phx-update={@update_mode} id={"menu-#{@package.id}"} data-offset="0" phx-hook="Select">
                    <button {testid("menu-btn-#{@package.id}")} title="Manage" type="button" class="btn-tertiary px-2 py-1 flex items-center flex-shrink-0 gap-1 mr-2 text-blue-planning-300 w-full">
                      Actions
                      <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
                      <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
                    </button>

                    <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content z-10">
                      <%= if !@package.archived_at do %>
                        <button title="Edit" type="button" phx-click="edit-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                          <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                          Edit
                        </button>

                        <button title="Duplicate" type="button" phx-click="duplicate-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                          <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                          Duplicate
                        </button>

                        <button title="Visibility" type="button" phx-click="edit-visibility-confirmation" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                          <.icon name={if @package.show_on_public_profile, do: "closed-eye", else: "eye"} class={classes("inline-block w-4 h-4 mr-3 fill-current", %{"text-blue-planning-300" => !@package.show_on_public_profile, "text-red-sales-300" => @package.show_on_public_profile})} />
                          <%= if @package.show_on_public_profile, do: "Hide on public profile", else: "Show on public profile" %>
                        </button>
                      <% end %>

                      <button {testid("archive-unarchive-btn-#{@package.id}")} title="Archive" type="button" phx-click="toggle-archive" phx-value-package-id={@package.id} phx-value-type={if @package.archived_at, do: "unarchive", else: "archive"} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                        <.icon name={if @package.archived_at, do: "plus", else: "trash"} class={classes("inline-block w-4 h-4 mr-3 fill-current", %{"text-blue-planning-300" => @package.archived_at, "text-red-sales-300" => !@package.archived_at})} />
                        <%= if @package.archived_at, do: "Unarchive", else: "Archive" %>
                      </button>
                    </div>
                  </div>
              </div>
          </div>
        </div>
      </div>
      <hr class="my-4 hidden md:block" />
    </div>
    """
  end

  @spec package_row(%{package: %Package{}}) :: %Phoenix.LiveView.Rendered{}
  def package_row(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: "",
        checked: false,
        inner_block: nil
      })

    assigns = assign_new(assigns, :can_edit?, fn -> true end)

    ~H"""
    <div class={classes("border p-3 sm:py-4 sm:border-b sm:border-t-0 sm:border-x-0 rounded-lg sm:rounded-none border-gray-100", %{"bg-gray-100" => @checked, "bg-base-200" => !@can_edit?})} {testid("template-card")}>
      <label class={classes("flex items-center justify-between cursor-pointer", %{"pointer-events-none cursor-nor-allowed" => !@can_edit?})}>
        <div class="w-1/3">
          <h3 class="font-xl font-bold mb-1"><%= @package.name %>—<%= dyn_gettext @package.job_type %></h3>
          <div class="flex flex-row-reverse items-center justify-end mt-auto">
            <.digital_detail id="package_detail" download_each_price={@package.download_each_price} download_count={@package.download_count}/>
          </div>
        </div>
        <div class="w-1/3 text-base-250">
          <p>Package price: <%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %></p>
          <p>Digitial image price: <%= if Money.zero?(@package.download_each_price) do %>--<% else %><%= @package.download_each_price %>/each<% end %></p>
        </div>
        <div class="w-1/3 text-center">
          <%= if @inner_block do %>
            <%= render_slot(@inner_block) %>
          <% end %>
        </div>
      </label>
    </div>
    """
  end

  def package_basic_fields(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-2 sm:gap-7">
      <%= labeled_input @form, :name, label: "Title", placeholder: "e.g. #{dyn_gettext @job_type} Deluxe", phx_debounce: "500", wrapper_class: "mt-4" %>
      <div class="grid gap-2 grid-cols-2 sm:contents">
        <%= labeled_select @form, :shoot_count, Enum.to_list(1..10), label: "# of Shoots", wrapper_class: "mt-4", class: "py-3", phx_update: "ignore" %>

        <div class="mt-4 flex flex-col">
          <div class="flex flex-row">
            <%= label_for @form, :turnaround_weeks, label: "Image Turnaround Time" %>
            <.intro_hint content="A general rule of thumb is you need to create your deadline not based on how soon you can deliver under ideal circumstances,
            but how long it could take you if you are extremely busy or had a major disruption to your workflow.
            You can deliver sooner than the turnaround time to surprise and delight your client." class="ml-1" />
          </div>
          <div>
            <%= input @form, :turnaround_weeks, type: :number_input, phx_debounce: "500", class: "w-1/3 text-center pl-6 mr-4", min: 1, max: 52 %>

            <%= ngettext("week", "weeks", Ecto.Changeset.get_field(@form.source, :turnaround_weeks)) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def print_credit_fields(assigns) do
    ~H"""
    <div class="border border-solid mt-6 p-6 rounded-lg">
      <% p = form_for(@package_pricing, "#") %>
      <.print_fields_heading />

      <div class="mt-4 font-normal text-base leading-6">
        <div class="mt-2">
          <label class="flex items-center font-bold">
            <%= radio_button(p, :is_enabled, true, class: "w-5 h-5 mr-2.5 radio") %>
            Gallery includes Print Credits
          </label>
          <div class="flex items-center gap-4 ml-7">
            <%= if p |> current() |> Map.get(:is_enabled) do %>
              <%= input(@f, :print_credits, placeholder: "$0.00", class: "mt-2 w-full sm:w-32 text-lg text-center font-normal", phx_hook: "PriceMask") %>
              <div class="flex items-center text-base-250">
                <%= label_for @f, :print_credits, label: "as a portion of Package Price", class: "font-normal" %>
              </div>
            <% end %>
          </div>
        </div>

        <label class="flex mt-3 font-bold">
          <%= radio_button(p, :is_enabled, false, class: "w-5 h-5 mr-2.5 radio mt-0.5") %>
          Gallery does not include Print Credits
        </label>
      </div>
    </div>
    """
  end

  # digital download fields for package & pricing
  def digital_download_fields(assigns) do
    assigns = Map.put_new(assigns, :for, nil)

    ~H"""
      <div class="border border-solid mt-6 p-6 rounded-lg">
        <% d = form_for(@download_changeset, "#") %>
        <.download_fields_heading title="Digital Collection" d={d} for={@for}>
          <p class="text-base-250">High-Resolution Digital Images available via download.</p>
        </.download_fields_heading>

        <.build_download_fields download_changeset={d} {assigns} />
      </div>
    """
  end

  defp download_fields_heading(assigns) do
    ~H"""
    <div class="mt-9 md:mt-1" {testid("download")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap"><%= @title %></h2>
      <%= if @for == :create_gallery || (get_field(@d, :status) == :limited) do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </div>
    """
  end

  defp build_download_fields(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row w-full mt-3">
      <div class="flex flex-col">
        <label class="flex font-bold">
          <%= radio_button(@download_changeset, :status, :limited, class: "w-5 h-5 mr-2 radio mt-0.5") %>
          <p>Set number of Digital Images included</p>
        </label>

        <%= if get_field(@download_changeset, :status) == :limited do %>
            <div class="flex flex-col mt-1">
              <div class="flex flex-row items-center">
                <%= input(
                  @download_changeset, :count, type: :number_input, phx_debounce: 200, step: 1,
                  min: 0, placeholder: "0", class: "mt-3 w-full sm:w-32 text-lg text-center md:ml-7"
                ) %>
                <span class="ml-2 text-base-250">included in the package</span>
              </div>
            </div>
        <% end %>

        <label class="flex mt-3 font-bold">
            <%= radio_button(@download_changeset, :status, :none, class: "w-5 h-5 mr-2 radio mt-0.5") %>
            <p>Charge for each Digital Image</p>
        </label>
        <span class="font-normal ml-7 text-base-250">(no images included)</span>
        <label class="flex mt-3 font-bold">
          <%= radio_button(@download_changeset, :status, :unlimited, class: "w-5 h-5 mr-2 radio mt-0.5") %>
          <p>All Digital Images included</p>
        </label>
      </div>
      <div class="my-8 border-t lg:my-0 lg:mx-8 lg:border-t-0 lg:border-l border-base-200"></div>
      <%= if get_field(@download_changeset, :status) in [:limited, :none] do %>
        <div class="ml-7 mt-3">
          <h3 class="font-bold">Pricing Options</h3>
          <p class="mb-3 text-base-250">The following digital image pricing is set in your Global Gallery Settings</p>
          <.include_download_price download_changeset={@download_changeset} />
          <.is_buy_all download_changeset={@download_changeset} />
        </div>
      <% end %>
    </div>
    """
  end

  defp is_buy_all(assigns) do
    ~H"""
    <label class="flex items-center mt-3 font-bold">
      <%= checkbox(@download_changeset, :is_buy_all, class: "w-5 h-5 mr-2.5 checkbox") %>
      <span>Offer a <i>Buy Them All</i> price for this package</span>
    </label>

    <%= if check?(@download_changeset, :is_buy_all) do %>
      <div class="flex flex-row items-center mt-3 lg:ml-7">
          <%= input(@download_changeset, :buy_all, placeholder: "$750.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
          <%= error_tag @download_changeset, :buy_all, class: "text-red-sales-300 text-sm ml-2" %>
          <span class="ml-3 text-base-250"> for all images </span>
      </div>
    <% end %>
    """
  end

  defp include_download_price(assigns) do
    ~H"""
    <div class="flex flex-col justify-between mt-3 sm:flex-row ">
      <div class="w-full sm:w-auto">
        <label class="flex font-bold items-center">
          <%= checkbox(@download_changeset, :is_custom_price, class: "w-5 h-5 mr-2.5 checkbox") %>
          <span>Change my per <i>Digital Image</i> price for this package</span>
        </label>
        <span class="font-normal ml-7 text-base-250">(<%= input_value(@download_changeset, :each_price)%>/each)</span>
        <%= if check?(@download_changeset, :is_custom_price) do %>
          <div class="flex flex-row items-center mt-3 lg:ml-7">
            <%= input(@download_changeset, :each_price, placeholder: "$50.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
            <%= error_tag @download_changeset, :each_price, class: "text-red-sales-300 text-sm ml-2" %>
            <span class="ml-3 text-base-250"> per image </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp digital_detail(assigns) do
    ~H"""
      <%= cond do %>
        <% Money.zero?(@download_each_price) -> %>
          <dt class="text-gray-500">All digital images included</dt>
        <% @download_count == 0 -> %>
          <dt class="text-gray-500">No digital images included</dt>
        <% true -> %>
          <dt class="text-gray-500">Digital images included</dt>
          <dd class="flex items-center justify-center w-8 h-8 mr-2 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
            <%= @download_count %>
          </dd>
      <% end %>
    """
  end

  defp print_fields_heading(assigns) do
    ~H"""
    <div class="mt-9 md:mt-1" {testid("print")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Professional Print Credit</h2>
      <p class="text-base-250">Print Credits allow your clients to order professional prints and products from your gallery.</p>
    </div>
    """
  end

  defp check?(d, field), do: d |> current() |> Map.get(field)
  defp get_field(d, field), do: d |> current() |> Map.get(field)

  def current(%{source: changeset}), do: current(changeset)
  def current(changeset), do: Ecto.Changeset.apply_changes(changeset)

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100

  defp truncate_package_name(name) do
    if(String.length(name) > 25, do: String.slice(name, 0..25) <> "...", else: name)
  end

  def assign_turnaround_weeks(package) do
    weeks =
      case package.turnaround_weeks do
        1 -> "1 week"
        num_weeks -> "#{num_weeks} weeks"
      end

    text = package.contract.content
    updated_content = Regex.replace(~r/(\d+)\s+(week\b|weeks\b)/, text, weeks)
    Map.put(package.contract, :content, updated_content)
  end
end
