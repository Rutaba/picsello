defmodule PicselloWeb.Live.Marketing.EditLinkComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{BrandLink, BrandLinks}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:brand_link, get_brand_link(assigns))
    |> assign_changeset(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={classes("modal", %{"hidden" => is_nil(@is_mobile)})}>
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="text-3xl font-bold">Edit Links</h1>
        <PicselloWeb.LiveModal.close_x />
      </div>
      <div class="flex">
        <div id="side-nave" class={classes("lg:grid grid-cols-1 p-5 mt-6 bg-gray-100 rounded-xl grid-container w-full lg:w-2/5 gap-y-2", %{"hidden" => !@is_mobile})}>
          <%= for entry <- @brand_links do %>
            <div class="font-bold bg-gray-200 text-base-250 rounded-lg cursor-pointer grid-item">
              <div phx-click="switch" phx-value-link_id={entry.link_id} phx-target={@myself} class={classes("brand-links", %{"text-base-250" => !entry.link})}>
                <div class={classes("flex items-center justify-center flex-shrink-0 rounded-full w-7 h-7 bg-blue-planning-300", %{"bg-base-250" => !entry.link})}>
                  <.icon name={get_brand_link_icon(entry.link_id)} class="h-3 w-3 text-base-100" />
                </div>
                <div class={classes("ml-2 truncate", %{"text-blue-planning-300" => entry.active?})}>
                  <span><%= entry.title %><span class={classes("font-normal", %{"hidden" => entry.use_publicly?})}> (private)</span></span>
                </div>
                <div class="flex items-center ml-auto">
                  <.icon name="tick" class={classes("inline-block w-4 h-4 text-blue-planning-300", %{"hidden" => !entry.show_on_profile?})}/>
                </div>
              </div>
              <span class={classes("hidden", %{"lg:block" => entry.link_id == @brand_link.link_id})}>
                <.icon name="arrow-filled" class="text-base-200 float-right w-8 h-8 -mt-10 -mr-10" />
              </span>
            </div>
          <% end %>
          <div phx-click="add_brand_link" phx-target={@myself} class="brand-links cursor-pointer">
            <div class="flex items-center justify-center flex-shrink-0 rounded-full w-7 h-7 bg-blue-planning-300">
              <.icon name="plus-bold" class="h-3 w-3 text-base-100 stroke-3" />
            </div>
            <div class="ml-2">
              <span class="text-blue-planning-300 font-bold underline">Add new link</span>
            </div>
          </div>
        </div>
        <div class={classes("lg:block w-full lg:ml-16 lg:mr-8", %{"hidden" => @is_mobile})}>
          <.form id="brand-link" :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
            <%= hidden_input f, :organization_id %>
            <%= hidden_input f, :link_id %>
            <.title_field form={f} class="mt-4" custom?={is_custom_brand_link(@brand_link.link_id)} link_id={@brand_link.link_id}/>
            <.link_field form={f} class="mt-5 pb-5" custom?={is_custom_brand_link(@brand_link.link_id)} link_id={@brand_link.link_id} placeholder="Add your link url…"/>
          </.form>
          <%= if !is_custom_brand_link(@brand_link.link_id) do %>
            <.check_box target={@myself} field="active?" brand_link={@brand_link} class={classes(%{"pointer-events-none opacity-50 cursor-not-allowed" => !@changeset.valid?})} label="Enable this link" content="You can only enable or disable prepoulated links"/>
          <% end %>
          <.check_box target={@myself} field="use_publicly?" brand_link={@brand_link} class={classes(%{"pointer-events-none opacity-50 cursor-not-allowed" => !@brand_link.active?})} label="Use link publicly?" content="If you mark your link as private, you won’t be able to use this link in email. For example, you are using this as a way to login to your social platform"/>
          <.check_box target={@myself} field="show_on_profile?" brand_link={@brand_link} class={classes(%{"pointer-events-none opacity-50 cursor-not-allowed" => !@brand_link.active?})} label="Show link in your Public Profile?" content="This link will appear in the footer of your public profile if you turn this on"/>
          <div class={classes(%{"hidden" => !is_custom_brand_link(@brand_link.link_id)})}>
            <div class="text-red-sales-300 mt-11 font-extrabold">
              Delete link
            </div>
            <div class="flex items-center flex-wrap justify-between">
              <p class="flex mt-0.5">
                If this link no longer sparks joy or you need to get rid of it, this is the place for you!
              </p>
              <button id="delete-link" phx-click="delete_brand_link" phx-target={@myself} class="flex text-red-sales-300 border-red-sales-300 border rounded-lg px-2 py-1 lg:mt-0 mt-4 font-semibold">
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-end flex-col gap-2 py-5 sm:flex-row-reverse">
        <button disabled={!@changeset.valid?} id="save" phx-click="save" phx-target={@myself} class="lg:flex hidden btn-primary lg:w-auto w-full" title="save" type="button" phx-click="submit" phx-disable-with="Saving...">
          Save
        </button>
        <button disabled={!@changeset.valid?} id="save_mobile" class={classes("lg:hidden btn-primary lg:w-auto w-full", %{"hidden" => @is_mobile})} phx-click="save_mobile" phx-target={@myself} title="save" type="button" phx-click="submit" phx-disable-with="Saving...">
          <span class="flex items-center justify-center">
            <.icon name="back" class="text-base-100 w-2 h-4 mr-2.5 stroke-2"/>
            Save & go back
          </span>
        </button>
        <button id="close" class={classes("btn-secondary lg:w-auto w-full", %{"hidden lg:flex" => @is_mobile})}  title="close" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
      </div>
    </div>
    """
  end

  defp title_field(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: "",
        placeholder: "",
        label: "Link Name",
        name: :title
      })

    ~H"""
    <label class={"flex flex-col #{@class}"}>
        <p class="py-2 font-extrabold"><%= @label %> <i class="italic font-light">(public facing or private logins)</i></p>

        <div class="relative flex flex-col">
          <%= input @form, @name,
              phx_debounce: "500",
              disabled: !@custom? && @link_id != "website",
              placeholder: @placeholder,
              class: classes("p-4", %{"bg-gray-200" => !@custom? && @link_id != "website"}) %>
          <%= error_tag @form, @name, class: "text-red-sales-300 text-sm", prefix: @label %>
        </div>
      </label>
    """
  end

  defp link_field(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: "",
        placeholder: "www.mystudio.com",
        label: "Link",
        sub_label: "",
        name: :link
      })

    ~H"""
    <label class={"flex flex-col #{@class}"}>
        <p class="py-2 font-extrabold"><%= @label %> <i class="italic font-light"><%= @sub_label %></i></p>

        <div class="relative flex flex-col">
          <%= input @form, @name,
              type: :url_input,
              phx_debounce: "500",
              placeholder: @placeholder,
              autocomplete: "url",
              novalidate: true,
              phx_hook: "PrefixHttp",
              class: "p-4" %>
          <%= error_tag @form, @name, class: "text-red-sales-300 text-sm", prefix: @label %>
        </div>
      </label>
    """
  end

  defp check_box(assigns) do
    ~H"""
    <label {testid(@field)} class={"flex items-center lg:order-2 order-1 mt-7 cursor-pointer #{@class}"}>
      <div class="font-sans font-extrabold" {intro_hints_only("intro_hints_only")}>
        <%= @label %>
        <.intro_hint class="ml-1" content={@content}/>
      </div>
      <div class="relative ml-auto">
        <input type="checkbox" class="sr-only" phx-value-field={@field} phx-click="toggle" phx-target={@target}>
        <%= if Map.get(@brand_link, String.to_existing_atom(@field)) do %>
          <div class="flex w-12 h-6 border rounded-full bg-blue-planning-300 border-base-100"></div>
          <div class="absolute w-4 h-4 rounded-full transition dot right-1 top-1 bg-base-100"></div>
        <% else %>
          <div class="block w-12 h-6 bg-gray-200 border rounded-full border-blue-planning-300"></div>
          <div class="absolute w-4 h-4 rounded-full transition dot left-1 top-1 bg-blue-planning-300"></div>
        <% end %>
      </div>
    </label>
    """
  end

  @impl true
  def handle_event("add_brand_link", _, %{assigns: %{brand_links: brand_links}} = socket) do
    count = brand_links |> Enum.filter(&String.contains?(&1.link_id, "link_")) |> length()

    brand_link = %BrandLink{
      title: "New link #{count + 1}",
      link_id: "link_#{count + 1}",
      active?: true,
      organization_id: List.first(brand_links) |> Map.get(:organization_id)
    }

    brand_links = update_link_ids(brand_links) ++ [brand_link]

    socket
    |> assign(:brand_link, brand_link)
    |> assign(:brand_links, brand_links)
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete_brand_link",
        _,
        %{assigns: %{is_mobile: is_mobile, brand_links: brand_links}} = socket
      ) do
    index = socket |> get_brand_link_index()
    updated_brand_link = brand_links |> Enum.at(index - 1)
    {brand_link, remaining_brand_links} = brand_links |> List.pop_at(index)

    unless is_nil(brand_link.id) do
      BrandLinks.delete_brand_link(brand_link)
    end

    updated_brand_links = update_link_ids(remaining_brand_links)

    send(socket.parent_pid, {:update_brand_links, updated_brand_links, "deleted"})

    socket
    |> assign(:brand_link, updated_brand_link)
    |> assign(:brand_links, updated_brand_links)
    |> assign_changeset()
    |> then(fn socket ->
      if is_mobile do
        socket |> assign(:is_mobile, !is_mobile)
      else
        socket
      end
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle",
        %{"field" => field},
        %{assigns: %{brand_link: brand_link, brand_links: brand_links}} = socket
      ) do
    index = socket |> get_brand_link_index()
    field = field |> String.to_existing_atom()
    brand_link = Map.put(brand_link, field, !Map.get(brand_link, field))

    brand_link =
      if brand_link.active? do
        brand_link
      else
        Map.merge(brand_link, %{use_publicly?: false, show_on_profile?: false})
      end

    socket
    |> assign(:brand_link, brand_link)
    |> assign(:brand_links, List.replace_at(brand_links, index, brand_link))
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event(
        "switch",
        %{"link_id" => link_id},
        %{assigns: %{is_mobile: is_mobile, brand_link: brand_link, brand_links: brand_links}} =
          socket
      ) do
    index = socket |> get_brand_link_index()

    socket
    |> assign(:is_mobile, !is_mobile)
    |> assign(:link_id, link_id)
    |> assign(:brand_link, Enum.find(brand_links, &(&1.link_id == link_id)))
    |> assign(:brand_links, List.replace_at(brand_links, index, brand_link))
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{"brand_link" => params},
        %{assigns: %{brand_link: brand_link, brand_links: brand_links}} = socket
      ) do
    socket
    |> assign_changeset(params)
    |> then(fn %{assigns: %{changeset: changeset}} = socket ->
      updated_brand_link = Map.merge(brand_link, changeset.changes)
      index = socket |> get_brand_link_index()

      updated_brand_link =
        cond do
          !changeset.valid? && !is_custom_brand_link(brand_link.link_id) ->
            Map.merge(updated_brand_link, %{
              active?: false,
              use_publicly?: false,
              show_on_profile?: false
            })

          !changeset.valid? ->
            Map.merge(updated_brand_link, %{use_publicly?: false, show_on_profile?: false})

          true ->
            updated_brand_link
        end

      socket
      |> assign(:brand_link, updated_brand_link)
      |> assign(:brand_links, List.replace_at(brand_links, index, updated_brand_link))
      |> noreply()
    end)
  end

  @impl true
  def handle_event("save", _, socket) do
    socket
    |> save()
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event("save_mobile", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket
    |> save()
    |> assign(:is_mobile, !is_mobile)
    |> noreply()
  end

  defp save(%{assigns: %{brand_links: brand_links}} = socket) do
    brand_links
    |> struct_to_map()
    |> remove_invalid_brand_links()
    |> BrandLinks.upsert_brand_links()
    |> case do
      [] ->
        socket

      brand_links ->
        send(socket.parent_pid, {:update_brand_links, brand_links, "updated"})
        socket
    end
  end

  def assign_changeset(
        %{assigns: %{brand_link: brand_link}} = socket,
        params \\ %{},
        action \\ :validate
      ) do
    changeset =
      brand_link
      |> BrandLink.update_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def open(%{assigns: assigns} = socket, link_id),
    do:
      socket
      |> open_modal(
        __MODULE__,
        %{
          assigns: assigns |> Map.take([:brand_links, :is_mobile]) |> Map.put(:link_id, link_id)
        }
      )

  defp get_brand_link(%{brand_links: brand_links, link_id: link_id}),
    do: brand_links |> Enum.find(&(&1.link_id == link_id))

  defp get_brand_link_index(%{assigns: %{brand_link: brand_link, brand_links: brand_links}}),
    do: brand_links |> Enum.find_index(&(&1.link_id == brand_link.link_id))

  defp struct_to_map(brand_links) do
    brand_links
    |> Enum.map(fn %{id: id} = brand_link ->
      case id do
        nil -> Map.from_struct(brand_link) |> Map.drop([:id, :__meta__, :organization])
        _ -> Map.from_struct(brand_link) |> Map.drop([:__meta__, :organization])
      end
    end)
  end

  defp update_link_ids(brand_links) do
    [presets | custom] =
      brand_links |> Enum.group_by(&String.contains?(&1.link_id, "link_")) |> Map.values()

    presets ++ Enum.with_index(List.flatten(custom), &Map.put(&1, :link_id, "link_#{&2 + 1}"))
  end

  defp remove_invalid_brand_links(brand_links),
    do:
      brand_links
      |> Enum.filter(&(BrandLink.create_changeset(%BrandLink{}, &1) |> Map.get(:valid?)))
end
