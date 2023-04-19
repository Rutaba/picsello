defmodule PicselloWeb.GalleryLive.Pricing.GalleryDigitalPricingComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared,
    only: [
      digital_download_fields: 1,
      print_credit_fields: 1,
      current: 1,
      check?: 2,
      get_field: 2
    ]

  alias Ecto.Changeset
  alias Picsello.{Repo, Galleries, GlobalSettings, Galleries.GalleryDigitalPricing, Packages.Download, Packages.PackagePricing}

  @impl true
  def update(%{current_user: current_user} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:package_pricing, fn -> %PackagePricing{} end)
    |> assign(:email_list, gallery.job.client.email)
    |> assign(
      global_settings:
        Repo.get_by(GlobalSettings.Gallery, organization_id: current_user.organization_id)
    )
    |> assign_changeset(%{}, nil)
    |> ok()
  end

  @impl true
  def render(assigns) do
    IO.inspect(assigns.download_changeset)
    ~H"""
    <div class="modal">
      <.close_x />

      <div>
        <h1 class="mt-2 mb-4 text-3xl font-bold">Edit digital pricing & credits</h1>
      </div>

      <.form for={@changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-digital-pricing-gallery-#{@gallery.id}"}>

      <div class="border border-solid mt-6 p-6 rounded-lg">
        <% p = to_form(@package_pricing) %>
        <div class="mt-9 md:mt-1" {testid("print")}>
          <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Professional Print Credit</h2>
          <p class="text-base-250">Print Credits allow your clients to order professional prints and products from your gallery.</p>
        </div>


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
                  <%= label_for f, :print_credits, label: "as a portion of Package Price", class: "font-normal" %>
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

      <hr class="block w-full mt-6 sm:hidden"/>

      <div class="border border-solid mt-6 p-6 rounded-lg">
        <div class="mt-9 md:mt-1" {testid("email_list")}>
          <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Restrict Print & Digital Image Credits</h2>
          <p class="text-base-250">Set who can use the print and digital image credits here via their email. Your client will be added automatically.</p>
        </div>

        <div class="mt-4 font-normal text-base leading-6">
          <%= form_tag("#", [phx_change: :validate_email, phx_submit: :add_email]) do %>
            <label class="flex mt-3 font-bold">Enter email</label>
            <div class="flex items-center gap-4">
              <input type="text" class="form-control text-input rounded" id="email_input" name="email" phx-debounce="100" spellcheck="false" placeholder="enter email..." />
              <button class="btn-primary" title="Add email" type="add_email">Add email</button>
            </div>
          <% end %>
        </div>

        <div class="mt-4 grid grid-rows-2 grid-flow-col gap-4 ">
          <div>
            <a class="flex items-center mt-2 hover:cursor-pointer">
              <.icon name="envelope" class="text-blue-planning-300 w-4 h-4" />
              <span class="text-base-250 ml-2 mr-20"><%= @gallery.job.client.email %> (client)</span>
              <button title="Trash" type="button" phx-click="delete-email" class="flex items-center px-2 py-2 bg-gray-100 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
              </button>
            </a>
            <hr class="block w-full mt-2"/>
          </div>
          <div>
            <a class="flex items-center mt-2 hover:cursor-pointer">
              <.icon name="envelope" class="text-blue-planning-300 w-4 h-4" />
              <span class="text-base-250 ml-2 mr-20"><%= @gallery.job.client.email %> (client)</span>
              <button title="Trash" type="button" phx-click="delete-email" class="flex items-center px-2 py-2 bg-gray-100 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
              </button>
            </a>
            <hr class="block w-auto mt-2"/>
          </div>
          <div>
            <a class="flex items-center mt-2 hover:cursor-pointer">
              <.icon name="envelope" class="text-blue-planning-300 w-4 h-4" />
              <span class="text-base-250 ml-2 mr-20"><%= @gallery.job.client.email %> (client)</span>
              <button title="Trash" type="button" phx-click="delete-email" class="flex items-center px-2 py-2 bg-gray-100 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
              </button>
            </a>
            <hr class="block w-full mt-2"/>
          </div>
          <div>
            <a class="flex items-center mt-2 hover:cursor-pointer">
              <.icon name="envelope" class="text-blue-planning-300 w-4 h-4" />
              <span class="text-base-250 ml-2 mr-20"><%= @gallery.job.client.email %> (client)</span>
              <button title="Trash" type="button" phx-click="delete-email" class="flex items-center px-2 py-2 bg-gray-100 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                <.icon name="trash" class="inline-block w-4 h-4 fill-current text-red-sales-300" />
              </button>
            </a>
            <hr class="block w-full mt-2"/>
          </div>
        </div>
      </div>

        <.footer class="pt-10">
          <button class="btn-primary" title="Save" type="submit" disabled={!@changeset.valid?}>Save</button>
        </.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate_email", {"email" => email}, socket) do
    email =
      email
      |> String.downcase()
      |> String.trim(email)

    valid_email? =
      email_list
      |> Enum.all?(fn email ->
        Repo.exists?(Clients.get_client_query(user, email: email))
      end)

      if String.match?(email, Picsello.Accounts.User.email_regex()) do
        socket
        |> assign(:email_error, nil)
        |> assign(:email_list, List.append(email_list, email))
      else
        socket
        |> assign(
          :email_error,
          "please enter valid client emails that already exist in the system"
        )
      end
      |> assign(:recipients, Map.put(recipients, type, email_list))
      |> then(fn socket -> re_assign_clients(socket) end)
      |> noreply()
  end

  defp validate_email_format(changeset, field) do
    changeset
    |> validate_format(field, Picsello.Accounts.User.email_regex(), message: "is invalid")
    |> validate_length(field, max: 160)
  end

  defp assign_changeset(%{assigns: %{gallery: gallery, global_settings: global_settings} = assigns} = socket, params, action \\ :validate) do
    changeset =
      GalleryDigitalPricing.changeset((if gallery.gallery_digital_pricing, do: gallery.gallery_digital_pricing, else: %GalleryDigitalPricing{}), params)
      |> Map.put(:action, action)

    download_params = Map.get(params, "download", %{}) |> Map.put("step", "pricing")

    download_changeset =
      gallery.gallery_digital_pricing
      |> Download.from_package(global_settings)
      |> IO.inspect()
      |> Download.changeset(download_params)
      |> IO.inspect
      |> Map.put(:action, action)

    download = current(download_changeset)

    package_pricing_changeset =
      assigns.package_pricing
      |> PackagePricing.changeset(
        Map.get(params, "package_pricing", gallery_pricing_params(gallery))
      )

    socket
    |> assign(
      changeset: changeset,
      package_pricing: package_pricing_changeset,
      download_changeset: download_changeset
    )
  end

  defp gallery_pricing_params(nil), do: %{}

  defp gallery_pricing_params(gallery) do
    case gallery |> Map.get(:print_credits) do
      %Money{} = value -> %{is_enabled: Money.positive?(value)}
      _ -> %{is_enabled: false}
    end
  end
end
