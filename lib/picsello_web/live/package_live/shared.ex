defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  use Phoenix.HTML
  use Phoenix.Component

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  import Phoenix.LiveView
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

  defp assign_brand_links(%{assigns: %{organization: organization}} = socket) do
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
        %{assigns: %{organization: organization}} = socket
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
      payload: %{changeset: changeset, job_type_id: id}
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

  @spec package_row(%{
          package: %Package{}
        }) :: %Phoenix.LiveView.Rendered{}
  def package_row(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: nil,
        update_mode: "ignore"
      })

    ~H"""
    <div class="border border-solid p-4 mb-3 ml-0 md:p-0 md:mb-0 md:ml-2 md:border-0">
      <div class="relative" {testid("package-template-card")}>
        <div class="flex items-center">
          <h1 title={@package.name} class="text-xl font-bold line-clamp-2 text-blue-planning-300 link hover:cursor-pointer" phx-click="edit-package" phx-value-package-id={@package.id}>
            <%=
              if String.length(@package.name) > 20 do
                String.slice(@package.name, 0..19) <> "..."
              else
                @package.name
              end
            %>
          </h1>
          <div class="flex items-center custom-tooltip" phx-click="edit-visibility-confirmation" phx-value-package-id={@package.id}>
            <.icon name={if @package.show_on_public_profile, do: "eye", else: "closed-eye"} class={classes("w-5 h-5 mx-2 hover:cursor-pointer", %{"text-gray-400" => !@package.show_on_public_profile, "text-blue-planning-300" => @package.show_on_public_profile})}/>
            <span class="shadow-lg rounded-lg py-1 px-2 text-xs">
              <%= if @package.show_on_public_profile, do: 'Shown on your Public Profile', else: 'Hidden on your Public Profile' %>
            </span>
          </div>
        </div>
        <div class="sm:flex sm:flex-row md:grid md:grid-cols-6">
          <div class={"flex flex-col col-span-2 group #{@class}"}>


            <div class="md:mb-4 relative" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="mouseover">
              <div class="line-clamp-2 raw_html raw_html_inline text-base-250">
                <%= raw @package.description %>
              </div>
              <div class="hidden md:block md:flex items-center">
                <span class="line-clamp-2 w-5 h-5 mr-2 flex justify-center text-xs font-bold rounded-full bg-gray-200 text-center">
                <%= @package.download_count %>
                </span>
                <span class="text-base-250">Downloadable photos</span>
              </div>
              <span class="hidden md:inline-block justify-start border rounded px-2 bg-blue-planning-100 text-blue-planning-300 font-bold text-xs"><%= @package.job_type %></span>
              <div class="hidden p-4 text-sm rounded bg-white font-sans shadow my-4 w-full absolute top-2 z-[15]" data-offset="0" role="tooltip">
                <div class="line-clamp-6 raw_html"></div>
                <button class="inline-block text-blue-planning-300">View all</button>
              </div>
              <%= if package_description_length_long?(@package.description) do %>
                <button class="inline-block text-blue-planning-300 view_more">View more</button>
              <% end %>
            </div>
          </div>

          <div class="col-span-2">
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
            <span class="line-clamp-2 w-5 h-5 mr-2 flex justify-center text-xs font-bold rounded-full bg-gray-200 text-center">
            <%= @package.download_count %>
            </span>
            <span class="text-base-250">Downloadable photos</span>
          </div>
          <span class="inline-block md:hidden justify-start border rounded px-2 bg-blue-planning-100 text-blue-planning-300 font-bold text-xs"><%= @package.job_type %></span>

          <div class="absolute top-0 right-0 block md:hidden ml-16 md:ml-2" phx-update={@update_mode} data-offset="0" phx-hook="Select">
            <button {testid("menu-btn-#{@package.id}")} title="Manage" type="button" class="flex flex-shrink-0 p-2 text-2xl font-bold bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
              <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

              <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
            </button>

            <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content w-64">
              <%= if !@package.archived_at do %>
                <button title="Edit" type="button" phx-click="edit-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                  <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                  Edit
                </button>

                <button title="Edit" type="button" phx-click="duplicate-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                  <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                  Duplicate
                </button>

                <button title="Edit" type="button" phx-click="edit-visibility-confirmation" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
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

          <div class="col-span-2">
            <div class="flex items-center">
                <div class="hidden md:block">
                  <%= if !@package.archived_at do %>
                    <.icon_button {testid("edit-package-#{@package.id}")} class="ml-5 border border-blue-planning-300 bg-white text-black font-normal" title="edit link" phx-click="edit-package" phx-value-package-id={@package.id} color="blue-planning-300" icon="pencil">
                      Edit package
                    </.icon_button>
                  <% end %>
                </div>
                <div class="hidden md:block ml-16 md:ml-2" phx-update={@update_mode} data-offset="0" phx-hook="Select">
                    <button {testid("menu-btn-#{@package.id}")} title="Manage" type="button" class="flex flex-shrink-0 p-2 text-2xl font-bold bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
                      <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

                      <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
                    </button>

                    <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content z-10">
                      <%= if !@package.archived_at do %>
                        <button title="Edit" type="button" phx-click="edit-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                          <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                          Edit
                        </button>

                        <button title="Edit" type="button" phx-click="duplicate-package" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
                          <.icon name="duplicate" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                          Duplicate
                        </button>

                        <button title="Edit" type="button" phx-click="edit-visibility-confirmation" phx-value-package-id={@package.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100">
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
      <%= if !@package.archived_at do %>
        <hr class="my-4 block md:hidden" />
      <% end %>
      <div class="flex items-center block md:hidden">
        <%= if !@package.archived_at do %>
          <.icon_button {testid("edit-package-#{@package.id}")} class="border border-blue-planning-300 bg-white text-black font-normal" title="edit link" phx-click="edit-package" phx-value-package-id={@package.id} color="blue-planning-300" icon="pencil">
            Edit package
          </.icon_button>
        <% end %>
      </div>
      <hr class="my-4 hidden md:block" />
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
    <% p = form_for(@package_pricing, "#") %>
    <.print_fields_heading />

    <div class="mt-4 font-normal text-base leading-6">
      <div class="mt-2">
        <label class="flex items-center">
          <%= radio_button(p, :is_enabled, true, class: "w-5 h-5 mr-2.5 radio") %>
          Gallery includes Print Credits
        </label>
        <div class="flex items-center gap-4 ml-7">
          <%= if p |> current() |> Map.get(:is_enabled) do %>
            <%= input(@f, :print_credits, placeholder: "$0.00", class: "mt-2 w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
            <div class="flex items-center">
              <%= label_for @f, :print_credits, label: "as a portion of Package Price", class: "font-normal" %>
            </div>
          <% end %>
        </div>
      </div>

      <label class="flex items-center mt-3">
        <%= radio_button(p, :is_enabled, false, class: "w-5 h-5 mr-2.5 radio") %>
        Gallery does not include Print Credits
      </label>
    </div>
    """
  end

  # digital download fields for package & pricing
  def digital_download_fields(assigns) do
    assigns = Map.put_new(assigns, :for, nil)

    ~H"""
    <% d = form_for(@download, "#") %>
    <.download_fields_heading
      title="Digital Collection"
      d={d}
      for={@for}
    >
      <p>High-Resolution Digital Images available via download.</p>
    </.download_fields_heading>

    <.build_download_fields d={d} {assigns} />
    """
  end

  defp download_fields_heading(%{d: d} = assigns) do
    ~H"""
    <div class="mt-6 sm:mt-9"  {testid("download")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap"><%= @title %></h2>
      <%= if @for == :create_gallery || check?(d, :is_enabled) do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </div>
    """
  end

  defp build_download_fields(%{for: key, d: d} = assigns) do
    ~H"""
    <div class="flex flex-col w-full mt-3">
      <label class="flex items-center">
        <%= radio_button(d, :is_enabled, true, class: "w-5 h-5 mr-2 radio") %>
        <%= package_or_gallery_content(@for) %> includes a specified number of Digital Images
      </label>

      <%= if check?(d, :is_enabled) do %>
        <div class="flex flex-col ml-7">
          <.set_download_price d={d} for={key} />
        </div>
      <% end %>

      <label class="flex items-center mt-3">
        <%= radio_button(d, :is_enabled, false, class: "w-5 h-5 mr-2 radio") %>
        <%= package_or_gallery_content(@for) %> includes unlimited digital downloads
      </label>

      <%= if @for == :create_gallery do %>
        <span class="italic ml-7">(Do not charge for any Digital Image)</span>
      <% end %>
    </div>
    """
  end

  defp is_buy_all(%{d: d} = assigns) do
    ~H"""
    <label class="flex items-center mt-3">
      <%= checkbox(d, :is_buy_all, class: "w-5 h-5 mr-2.5 checkbox") %>
      <span>Set a <em>Buy Them All</em> price</span>
    </label>

    <%= if check?(d, :is_buy_all) do %>
      <div class="flex items-center mt-3 md:ml-7">
        <%= input(d, :buy_all, placeholder: "$750.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
        <%= error_tag d, :buy_all, class: "text-red-sales-300 text-sm ml-2" %>
      </div>
    <% end %>
    """
  end

  defp include_download_price(%{d: d} = assigns) do
    ~H"""
    <div class="flex flex-col justify-between mt-3 sm:flex-row ">
      <div class="w-full sm:w-auto">
        <label class="flex items-center">
          <%= checkbox(d, :is_custom_price, class: "w-5 h-5 mr-2.5 checkbox") %>
          <span>Set my own <em>per Digital Image</em> price</span>
        </label>
        <%= if check?(d, :is_custom_price) do %>
          <div class="flex items-center mt-3 ml-7 mt-3">
            <%= input(d, :each_price, class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
            <%= error_tag d, :each_price, class: "text-red-sales-300 text-sm ml-2" %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp set_download_price(%{for: key, d: d} = assigns) do
    ~H"""
    <label class="flex items-center mt-3">
      <%= checkbox(d, :includes_credits, class: "w-5 h-5 mr-2.5 checkbox") %>
      Digital Images are included in the <%= package_or_gallery_content(key) |> String.downcase() %>
    </label>
    <%= if check?(d, :includes_credits) do %>
      <%= input(
        d, :count, type: :number_input, phx_debounce: 200, step: 1,
        min: 1, placeholder: 1, class: "mt-3 w-full sm:w-32 text-lg text-center md:ml-7"
      ) %>
      <div class="ml-7 mt-3">
        <h3 class="font-bold">Upsell options</h3>
        <p class="mb-3">For additional Digital Images beyond what’s included in the <%= package_or_gallery_content(key) |> String.downcase() %></p>
        <.include_download_price d={d} />
        <.is_buy_all d={d} />
      </div>
    <% end %>
    """
  end

  defp digital_detail(assigns) do
    ~H"""
      <%= cond do %>
        <%= Money.zero?(@download_each_price) -> %>
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
    <div class="mt-6 sm:mt-9" {testid("print")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Professional Print Credit</h2>
      <p>Print Credits allow your clients to order professional prints and products from your gallery.</p>
    </div>
    """
  end

  defp check?(d, field), do: d |> current() |> Map.get(field)

  def current(%{source: changeset}), do: current(changeset)
  def current(changeset), do: Ecto.Changeset.apply_changes(changeset)

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100

  defp package_or_gallery_content(key) do
    if key == :create_gallery do
      "Gallery"
    else
      "Package"
    end
  end
end
