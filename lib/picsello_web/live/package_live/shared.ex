defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  use Phoenix.HTML
  use Phoenix.Component

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
          package: Package.t(),
          is_edit: boolean()
        }) :: Phoenix.LiveView.Rendered.t()
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

  @spec package_template_row(%{package: Package.t(), update_mode: String.t()}) ::
          Phoenix.LiveView.Rendered.t()
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

  @spec package_row(%{package: Package.t(), checked: boolean()}) :: Phoenix.LiveView.Rendered.t()
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
      <% p = to_form(@package_pricing) %>
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

  def package_print_credit_fields(assigns) do
    ~H"""
    <div class="flex">
      <% p = to_form(@package_pricing) %>
      <% print_credits = current(p) %>
      <div class="flex flex-col w-4/5">
        <.print_fields_heading />
        <button class="underline text-blue-planning-300 mt-auto inline-block w-max" type="button" phx-target={@target} phx-click="edit-print-credits">Edit settings</button>
      </div>
      <div class={classes("flex w-1/5", %{"text-base-250 grid" => !Map.get(print_credits, :print_credits_include_in_total)})}>
        <div><b><%= get_total_print_credits(@f, @package_pricing) %></b></div>
        <%= if Map.get(print_credits, :is_enabled) && !Map.get(print_credits, :print_credits_include_in_total) do %>
          <div class="text-base-250 -mt-10">(not included)</div>
        <% end %>
      </div>
    </div>

    <div class={classes("border border-solid mt-6 rounded-lg w-1/2", %{"hidden" => !@show_print_credits})}>
      <div class="p-2 font-bold bg-base-200 flex flex-row">
        Print credit settings
        <a phx-target={@target} phx-click="edit-print-credits" class="flex items-center cursor-pointer ml-auto"><.icon name="close-x" class="w-3 h-3 stroke-current stroke-2"/></a>
      </div>

      <div class="mt-4 font-normal text-base leading-6 pb-6 px-6">
        <div class="mt-2">
          <label class="flex items-center font-bold">
            <%= radio_button(p, :is_enabled, true, class: "w-5 h-5 mr-2.5 radio") %>
            Gallery includes Print Credits
          </label>
          <div class="flex flex-col gap-4 ml-7">
            <%= if Map.get(print_credits, :is_enabled) do %>
              <%= input(@f, :print_credits, placeholder: "$0.00", class: "mt-2 w-full sm:w-32 text-lg text-center font-normal", phx_hook: "PriceMask") %>

              <div class="flex items-center text-base-250">
                <%= checkbox(p, :print_credits_include_in_total, class: "w-5 h-5 mr-2.5 checkbox") %>
                <%= label_for p, :print_credits_include_in_total, label: "Include in package total calculation", class: "font-normal" %>
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
      <div class="flex mt-6">
        <% d = to_form(@download_changeset) %>
        <div class="flex-col gap-3 w-4/5">
          <div class="flex flex-col w-4/5 items-center md:items-start">
            <h2 class="mb-1 text-xl font-bold">Digital Collection</h2>
            <span class="text-base-250">High-Resolution Digital Images available via download.</span>
          </div>
          <div class="flex flex-row gap-8 my-2">
            <div>
              <span class="flex flex-row items-center mb-2"><.icon name="tick" class="w-6 h-5 mr-1 text-green" /><%= make_digital_text(@download_changeset) %> included</span>
              <button class="underline text-blue-planning-300 mt-auto inline-block w-max" type="button" phx-target={@target} phx-value-type="digitals" phx-click="edit-digitals">Edit settings</button>
            </div>
            <div>
              <span class="flex flex-row items-center mb-2"><.icon name="tick" class="w-6 h-5 mr-1 text-green" /><%= current(@download_changeset) |> Map.get(:each_price) %> an image</span>
              <%= if (@download_changeset |> current |> Map.get(:status)) !=  :unlimited do %>
                <button class="underline text-blue-planning-300 mt-auto inline-block w-max" type="button" phx-target={@target} phx-value-type="image_price" phx-click="edit-digitals">Edit image price</button>
              <% end %>
            </div>
            <div>
              <span class="flex flex-row items-center mb-2"><.icon name="tick" class="w-6 h-5 mr-1 text-green" /><%= get_buy_all(@download_changeset) %> buy all</span>
              <%= if (@download_changeset |> current |> Map.get(:status)) !=  :unlimited do %>
                <button class="underline text-blue-planning-300 mt-auto inline-block w-max" type="button" phx-target={@target} phx-value-type="buy_all" phx-click="edit-digitals">Edit upsell options</button>
              <% end %>
            </div>
          </div>
        </div>
        <b class="flex w-1/5"><%= digitals_total(@download_changeset) %></b>
      </div>

      <div class={classes("border border-solid mt-6 rounded-lg w-1/2", %{"hidden" => @show_digitals !== "digitals"})}>
        <div class="p-2 font-bold bg-base-200 flex flex-row">
          Digital Collection Settings
          <a phx-target={@target} phx-value-type="close" phx-click="edit-digitals" class="flex items-center cursor-pointer ml-auto"><.icon name="close-x" class="w-3 h-3 stroke-current stroke-2"/></a>
        </div>
        <.build_download_fields download_changeset={d} {assigns} />
      </div>

      <div class={classes("border border-solid mt-6 rounded-lg w-1/2", %{"hidden" => @show_digitals !== "image_price"})}>
        <div class="p-2 font-bold bg-base-200 flex flex-row">
          Digital Image Price
          <a phx-target={@target} phx-value-type="close" phx-click="edit-digitals" class="flex items-center cursor-pointer ml-auto"><.icon name="close-x" class="w-3 h-3 stroke-current stroke-2"/></a>
        </div>
        <.include_download_price download_changeset={d} />
      </div>

      <div class={classes("border border-solid mt-6 rounded-lg w-1/2", %{"hidden" => @show_digitals !== "buy_all"})}>
        <div class="p-2 font-bold bg-base-200 flex flex-row">
          Upsell Options
          <a phx-target={@target} phx-value-type="close" phx-click="edit-digitals" class="flex items-center cursor-pointer ml-auto"><.icon name="close-x" class="w-3 h-3 stroke-current stroke-2"/></a>
        </div>
        <.is_buy_all download_changeset={d} />
      </div>
    """
  end

  # defp download_fields_heading(assigns) do
  #   ~H"""
  #   <div class="mt-9 md:mt-1" {testid("download")}>
  #     <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap"><%= @title %></h2>
  #     <%= if @for == :create_gallery || (get_field(@d, :status) == :limited) do %>
  #       <%= render_slot(@inner_block) %>
  #     <% end %>
  #   </div>
  #   """
  # end

  defp build_download_fields(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row w-full mt-4 px-6 pb-6">
      <div class="flex flex-col">
        <label class="flex font-bold">
          <%= radio_button(@download_changeset, :status, :limited, class: "w-5 h-5 mr-2 radio mt-0.5") %>
          <p>Clients don’t have to pay for some Digital Images</p>
        </label>
        <i class="font-normal ml-7 text-base-250">(Charge for some Digital Images)</i>

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
          <%= if @for != :create_gallery do %>
            <div class="flex items-center text-base-250 ml-7 mt-2">
              <%= checkbox(@download_changeset, :digitals_include_in_total, class: "w-5 h-5 mr-2.5 checkbox") %>
              <%= label_for @download_changeset, :digitals_include_in_total, label: "Include in package total calculation", class: "font-normal" %>
            </div>
          <% end %>
        <% end %>

        <label class="flex mt-3 font-bold">
            <%= radio_button(@download_changeset, :status, :none, class: "w-5 h-5 mr-2 radio mt-0.5") %>
            <p>Clients have to pay for all Digital images</p>
        </label>
        <i class="font-normal ml-7 text-base-250">(Charge for all Digital Images)</i>
        <label class="flex mt-3 font-bold">
          <%= radio_button(@download_changeset, :status, :unlimited, class: "w-5 h-5 mr-2 radio mt-0.5") %>
          <p>Clients have Unlimited Digital Images</p>
        </label>
        <i class="font-normal ml-7 text-base-250">(Do not charge for any Digital Image)</i>
      </div>
    </div>
    """
  end

  defp is_buy_all(assigns) do
    ~H"""
    <div class="mt-4 px-6 pb-6 flex flex-col justify-between">
      <div class="text-base-250">This is optional, but if you’d like to provide your client with the opportunity to buy all images in the gallery, set that here</div>
      <label class="flex items-center mt-3 font-bold">
        <%= checkbox(@download_changeset, :is_buy_all, class: "w-5 h-5 mr-2.5 checkbox") %>
        <span>Set a <i>Buy Them All</i> price</span>
      </label>

      <%= if check?(@download_changeset, :is_buy_all) do %>
        <div class="flex flex-row items-center mt-3 lg:ml-7">
            <%= input(@download_changeset, :buy_all, placeholder: "$750.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
            <%= error_tag @download_changeset, :buy_all, class: "text-red-sales-300 text-sm ml-2" %>
            <span class="ml-3 text-base-250"> for all images </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp include_download_price(assigns) do
    ~H"""
    <div class="flex flex-col justify-between mt-4 sm:flex-row px-6 pb-6">
      <div class="w-full sm:w-auto">
        <span class="text-base-250">We default to the price you set in global gallery settings, you can override here for this package</span>
        <div class="flex flex-row items-center mt-3 lg:ml-7">
          <%= input(@download_changeset, :each_price, placeholder: "$50.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
          <%= error_tag @download_changeset, :each_price, class: "text-red-sales-300 text-sm ml-2" %>
          <span class="ml-3 text-base-250"> per image </span>
        </div>
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
    <div class="mt-9 md:mt-1 mb-2" {testid("print")}>
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

  def digitals_total(download_changeset) do
    changeset = current(download_changeset)
    if Map.get(changeset, :digitals_include_in_total), do: Money.multiply(Map.get(changeset, :each_price), get_digitals_count(download_changeset)), else: nil
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

  defp truncate_package_name(name) do
    if(String.length(name) > 25, do: String.slice(name, 0..25) <> "...", else: name)
  end

  defp get_digitals_count(download_changeset) do
    changeset = current(download_changeset)
    count = Map.get(changeset, :count)
    if count, do: count, else: 0
  end

  defp make_digital_text(download_changeset) do
    case download_changeset |> current() |> Map.get(:status) do
      :unlimited -> "all images"
      _ ->
        ngettext("%{count} image", "%{count} images", get_digitals_count(download_changeset))
    end
  end

  defp get_buy_all(download_changeset) do
    changeset = current(download_changeset)
    buy_all = Map.get(changeset, :buy_all)
    if buy_all, do: buy_all, else: Money.new(0)
  end
  
  defp get_total_print_credits(changeset, package_pricing) do
    package_pricing = package_pricing |> current()
    print_credits = changeset |> current() |> Map.get(:print_credits)
    if Map.get(package_pricing, :is_enabled), do: print_credits, else: nil
  end
end
