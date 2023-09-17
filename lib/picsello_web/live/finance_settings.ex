defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]

  alias Ecto.Multi

  alias Picsello.{
    Payments,
    Package,
    GlobalSettings,
    Currency,
    UserCurrencies,
    Utils,
    ExchangeRatesApi,
    Organization,
    Accounts,
    SearchComponent,
    Repo
  }

  alias PicselloWeb.SearchComponent

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    user_currency = UserCurrencies.get_user_currency(current_user.organization.id)

    socket
    |> assign(:page_title, "Settings")
    |> assign_stripe_status()
    |> assign_payment_options_changeset(%{})
    |> assign(user_currency: user_currency)
    |> assign(organization: current_user.organization)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user} intro_id="intro_settings_finances">
      <div class="flex flex-col justify-between flex-1 flex-grow-0 mt-5 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Finances</h1>
        </div>
      </div>
      <hr class="my-4 sm:my-10" />
      <div class="grid gap-6 sm:grid-cols-2">
        <.card title="Stripe account" class="intro-stripe">
          <p class="mt-2 text-base-250">Picsello uses Stripe so your payments are always secure. View and manage your payments through your Stripe account.</p>
          <div class="flex mt-6 justify-end">
            <%= live_component PicselloWeb.StripeOnboardingComponent, id: :stripe_onboarding,
            error_class: "text-right",
            class: "px-8 text-center btn-primary sm:w-auto w-full",
            container_class: "sm:w-auto w-full",
            current_user: @current_user,
            return_url: Routes.home_url(@socket, :index),
            stripe_status: @stripe_status %>
          </div>
        </.card>
        <.card title="Currency" class="intro-taxes">
          <p class="mt-2 text-base-250">For non-US countries supported by Stripe, you can adjust settings to reflect and charge clients in your native currency. To confirm if your currency is supported, <a class="underline" href="https://stripe.com/docs/currencies" target="_blank" rel="noopener noreferrer">go to Stripe.</a></p>
          <b class=" mt-6">Selected</b>
          <div class="flex md:flex-row flex-col justify-between gap-4">
            <div class="flex items-center flex-col">
              <p class="text-center inline-block bg-base-200 py-2 px-8 rounded-lg align-middle sm:w-auto w-full"><%= @user_currency.currency %></p>
            </div>
            <a class="text-center block btn-primary sm:w-auto w-full cursor-pointer" phx-click="choose_currency">
              Edit
            </a>
          </div>
        </.card>
      </div>
      <div class="grid gap-6 mt-6">
        <.card title="Accepted payment types" class="intro-payments">
          <p class="mt-2 text-base-250">Here you can enable payment methods you would like to accept. Note, payment methods available may be contingent upon the currency selected.</p>
          <.form :let={f} for={@payment_options_changeset} phx-change="update-payment-options">
            <%= inputs_for f, :payment_options, fn fp -> %>
              <%= hidden_inputs_for(fp) %>
              <%= if @user_currency.currency in Utils.payment_options_currency() do %>
                <div>
                  <h3 class="font-bold text-xl mb-3 mt-4">Via Stripe Online</h3>
                  <hr class=""/>
                  <div class="grid gap-6 sm:gap-x-16 sm:gap-y-4 sm:grid-cols-2">
                    <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Afterpay" description="Buy now pay later" input_name={:allow_afterpay_clearpay} f={fp} icon="payment-afterpay" />
                    <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Klarna" description="Make sure to add Klarna in your Stripe account payment settings" input_name={:allow_klarna} f={fp} icon="payment-klarna" />
                    <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Affirm" description="Make sure to add Affirm in your Stripe account payment settings" input_name={:allow_affirm} f={fp} icon="payment-affirm" />
                    <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Cash App Pay" description="Pay with CashApp" input_name={:allow_cashapp} f={fp} icon="payment-cashapp" />
                  </div>
                </div>
              <% end %>
              <div>
                <h3 class="font-bold text-xl mb-3 mt-6">Via Manual Methods</h3>
                <hr class="" />
                <div class="grid gap-6 sm:gap-16 sm:grid-cols-2">
                  <.toggle current_user={@current_user} heading="Manual" description="All others including Cash, Check, Venmo, etc." input_name={:allow_cash} f={fp} />
                </div>
              </div>
            <% end %>
          </.form>
        </.card>
      </div>
      <div class="grid gap-6 sm:grid-cols-2 mt-6">
        <.card title="Tax info" class="intro-taxes">
          <p class="mt-2 text-base-250">Stripe can easily manage your tax settings to simplify filing.</p>
          <a class="link" target="_blank" href="https://support.picsello.com/article/113-stripe-taxes">Do I need this?</a>
          <div class="flex mt-6 justify-end">
            <%= if @stripe_status == :charges_enabled do %>
              <a class="text-center block btn-primary sm:w-auto w-full" href="https://dashboard.stripe.com/settings/tax" target="_blank" rel="noopener noreferrer">
                View tax settings in Stripe
              </a>
            <% else %>
              <div class="flex flex-col sm:w-auto w-full">
                <button class="btn-primary" disabled>View tax settings in Stripe</button>
                <em class="block pt-1 text-xs text-center">Set up Stripe to view tax settings</em>
              </div>
            <% end %>
          </div>
        </.card>
      </div>
    </.settings_nav>
    """
  end

  def toggle(assigns) do
    assigns =
      Enum.into(assigns, %{
        stripe_status: :charges_enabled,
        icon: nil
      })

    ~H"""
    <div class={classes("grid grid-cols-2 sm:grid-cols-1 lg:grid-cols-2 items-center mt-2 justify-between" , %{"opacity-50 pointer-events-none" => !Enum.member?([:charges_enabled, :loading], @stripe_status)})}>
      <div class="flex">
        <%= if @icon do %>
          <.icon name={@icon} class="mr-2 mt-2 w-6 h-6 flex-shrink-0" />
        <% end %>
        <div>
          <p class="font-semibold"><%= @heading %></p>
          <p class="font-normal flex text-base-250"><%= @description %></p>
        </div>
      </div>
      <div class="flex justify-end sm:justify-start lg:justify-end items-center">
        <label class="mt-4 text-lg flex">
          <%= checkbox(@f, @input_name, class: "peer hidden", disabled: !Enum.member?([:charges_enabled, :loading], @stripe_status)) %>
          <div class="hidden peer-checked:flex cursor-pointer">
            <div class="rounded-full bg-blue-planning-300 border border-base-100 w-12 p-1 flex justify-end mr-4">
              <div class="rounded-full h-5 w-5 bg-base-100"></div>
            </div>
            Enabled
          </div>
          <div class="flex peer-checked:hidden cursor-pointer">
            <div class="rounded-full w-12 p-1 flex mr-4 border border-blue-planning-300">
              <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
            </div>
            Disabled
          </div>
        </label>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  def handle_event(
        "update-payment-options",
        %{"organization" => %{"payment_options" => payment_options}},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    changeset =
      build_payment_options_changeset(
        socket,
        %{
          payment_options: payment_options
        },
        nil
      )

    case Repo.update(changeset) do
      {:ok, _organization} ->
        socket
        |> assign(
          current_user: Accounts.get_user!(current_user.id) |> Repo.preload(:organization)
        )
        |> assign_payment_options_changeset(%{})
        |> put_flash(:success, "Payment options updated")
        |> noreply()

      {:error, _changeset} ->
        socket
        |> assign_payment_options_changeset(%{})
        |> put_flash(:error, "Couldn't update option. Try again or contact support.")
        |> noreply()
    end
  end

  def handle_event(
        "choose_currency",
        %{},
        %{assigns: %{user_currency: %{currency: currency}}} = socket
      ) do
    socket
    |> SearchComponent.open(%{
      selection: %{id: currency, name: currency},
      change_event: :change_currency,
      submit_event: :submit_currency,
      title: "Edit Currency",
      subtitle:
        "Enter the three letter currency code below to search, select and save your native currency.",
      component_used_for: :currency,
      warning_note: """
      Printed gallery products are fulfilled through our US-based lab partner, White House Custom Color
      (WHCC) so currently, non-US clients will be unable to order products through their Picsello gallery.
      """
    })
    |> noreply()
  end

  @impl true
  def handle_info(
        {:search_event, :change_currency, search},
        %{assigns: %{modal_pid: modal_pid}} = socket
      ) do
    send_update(modal_pid, SearchComponent,
      id: SearchComponent,
      results: Currency.search(search) |> Enum.map(&%{id: &1.code, name: &1.code}),
      search: search,
      selection: nil
    )

    socket
    |> noreply
  end

  def handle_info(
        {:search_event, :submit_currency, %{name: new_currency}},
        %{
          assigns: %{
            user_currency: user_currency,
            current_user: %{organization: organization} = current_user
          }
        } = socket
      ) do
    rate = ExchangeRatesApi.get_latest_rate(user_currency.currency, new_currency)

    {:ok, %{update_user_currency: user_currency}} =
      GlobalSettings.update_currency(user_currency, %{
        currency: new_currency,
        previous_currency: user_currency.currency,
        exchange_rate: rate
      })

    {:ok, _} = convert_packages_currencies(current_user, user_currency)
    maybe_disable_sell_global_products(new_currency, organization.id)
    maybe_disable_payment_options(new_currency, organization)

    socket
    |> assign(:user_currency, user_currency)
    |> put_flash(:success, "Currency updated")
    |> close_modal()
    |> noreply
  end

  def handle_info(
        {:close_event, "toggle_close_event"},
        socket
      ) do
    socket
    |> push_redirect(to: Routes.finance_settings_path(socket, :index))
    |> close_modal()
    |> noreply()
  end

  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  defp convert_packages_currencies(
         current_user,
         %{currency: currency, exchange_rate: rate} = _user_currency
       ) do
    package_templates =
      Package.templates_for_organization_query(current_user.organization.id)
      |> Repo.all()

    required_keys = [:base_price, :download_each_price, :print_credits]

    package_templates
    |> Enum.reduce(Multi.new(), fn package_template, multi ->
      params =
        Enum.reduce(required_keys, %{}, fn key, acc ->
          value = Map.get(package_template, key) |> convert_currency(currency, rate)
          Map.put(acc, key, value)
        end)
        |> Map.put(:currency, currency)

      changeset = Package.update_pricing(package_template, params)

      package_template
      |> Repo.preload(:package_payment_schedules, force: true)
      |> Map.get(:package_payment_schedules)
      |> Enum.reduce(multi, fn payment_schedule, multi ->
        if payment_schedule.price do
          payment_schedule_params = %{
            price: payment_schedule.price |> convert_currency(currency, rate),
            description:
              "#{currency}#{payment_schedule.price} to #{payment_schedule.due_interval}"
          }

          Multi.update(
            multi,
            "update_payment_schedule_#{payment_schedule.id}",
            Ecto.Changeset.change(payment_schedule, payment_schedule_params)
          )
        else
          multi
        end
      end)
      |> Multi.update("update_package_#{package_template.id}", changeset)
    end)
    |> Repo.transaction()
  end

  defp convert_currency(%{amount: amount}, currency, rate) do
    Money.new(amount, currency) |> Money.multiply(rate)
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end

  defp maybe_disable_sell_global_products(currency, organization_id) do
    gallery_products = GlobalSettings.list_gallery_products(organization_id)

    for gallery_product <- gallery_products do
      if currency in Utils.products_currency() do
        GlobalSettings.update_gallery_product(gallery_product, %{sell_product_enabled: true})
      else
        GlobalSettings.update_gallery_product(gallery_product, %{sell_product_enabled: false})
      end
    end
  end

  defp maybe_disable_payment_options(
         currency,
         %{payment_options: payment_options} = organization
       ) do
    updated_payment_options =
      payment_options
      |> Map.from_struct()
      |> Enum.map(fn {payment_option, enabled?} ->
        case payment_option do
          :allow_cash ->
            {payment_option, enabled?}

          _ ->
            if currency in Utils.payment_options_currency(payment_option) do
              {payment_option, enabled?}
            else
              {payment_option, false}
            end
        end
      end)
      |> Map.new()

    build_payment_options_changeset(
      %{assigns: %{current_user: %{organization: organization}}},
      %{
        payment_options: updated_payment_options
      },
      :update
    )
    |> Repo.update()
  end

  defp build_payment_options_changeset(
         %{assigns: %{current_user: %{organization: organization}}},
         params,
         action
       ) do
    organization
    |> Organization.payment_options_changeset(params)
    |> Map.put(:action, action)
  end

  defp assign_payment_options_changeset(
         socket,
         params,
         action \\ nil
       ) do
    changeset = build_payment_options_changeset(socket, params, action)

    socket
    |> assign(payment_options_changeset: changeset)
  end
end
