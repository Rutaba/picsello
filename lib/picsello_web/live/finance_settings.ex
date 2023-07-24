defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  require Logger
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]

  alias Ecto.Multi

  alias Picsello.{
    Payments,
    Package,
    Accounts.User,
    GlobalSettings,
    Currency,
    UserCurrencies,
    Utils,
    ExchangeRatesApi
  }

  alias PicselloWeb.SearchComponent
  alias Picsello.Repo

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    Logger.info("#{current_user.organization.id} is the org_id")
    user_currency = UserCurrencies.get_user_currency(current_user.organization.id)

    socket
    |> assign(:page_title, "Settings")
    |> assign_stripe_status()
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
        <.card title="Accepted payment types" class="intro-payments">
          <p class="mt-2 text-base-250">Here you can enable if you’d like to accept offline payments. Be careful, you are opening yourself up to more manual work!</p>
          <p class="font-bold mt-4">I would like to accept:</p>
          <div class="flex items-center mt-2 justify-between">
            <div class="flex flex-col">
              <p class="font-semibold">Cash/check payments</p>
              <p class="font-normal flex text-base-250">Accept offline payments</p>
            </div>
            <div class="flex justify-end items-center">
              <.form :let={_} for={%{}} as={:toggle} phx-change="toggle">
                <label class="mt-4 text-lg flex">
                  <input type="checkbox" class="peer hidden" checked={User.enabled?(@current_user)}/>
                  <div class="hidden peer-checked:flex cursor-pointer">
                    <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                      <div class="rounded-full h-5 w-5 bg-base-100"></div>
                    </div>
                    Enabled
                  </div>
                  <div class="flex peer-checked:hidden cursor-pointer">
                    <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                      <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                    </div>
                    Disabled
                  </div>
                </label>
              </.form>
            </div>
            </div>
        </.card>
      </div>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  def handle_event(
        "toggle",
        %{},
        %{assigns: %{current_user: %{allow_cash_payment: false}}} = socket
      ) do
    PicselloWeb.ConfirmationComponent.open(socket, %{
      close_event: "toggle_close_event",
      close_label: "No, go back",
      confirm_event: "allow-cash",
      confirm_label: "Yes, allow cash/check",
      icon: "warning-orange",
      title: "Are you sure?",
      subtitle:
        "Are you sure you want to allow cash and checks as a payment option? \n\nYou will need to communicate directly with your client to capture payment and manually enter those into your job payment details."
    })
    |> noreply()
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
      subtitle: "Change your Picsello account settings to charge clients in your native currency",
      component_used_for: :currency,
      warning_note: """
      Printed gallery products are fulfilled through our US-based lab partner, White House Custom Color
      (WHCC) so currently, non-US clients will be unable to order products through their Picsello gallery.
      <br><br>
      We are working on updates for self-fulfillment and ad-hoc invoice features to provide you with alternate
      options for release in late 2023. In 2024–26, we'll be exploring alternate print lab partners so
      <a class="chat text-blue-planning-300 underline" href="https://support.picsello.com/" rel="noopener noreferrer" target="_blank">let us know</a>
       if you have a favorite.
      """
    })
    |> noreply()
  end

  def handle_event(
        "toggle",
        %{},
        %{assigns: %{current_user: %{allow_cash_payment: true} = current_user}} = socket
      ) do
    socket
    |> assign(current_user: User.toggle(current_user))
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
        %{assigns: %{user_currency: user_currency, current_user: current_user}} = socket
      ) do
    Logger.info("#{user_currency.currency} is the currency")
    rate = ExchangeRatesApi.get_latest_rate(user_currency.currency, new_currency)

    {:ok, %{update_user_currency: user_currency}} =
      GlobalSettings.update_currency(user_currency, %{
        currency: new_currency,
        previous_currency: user_currency.currency,
        exchange_rate: rate
      })

    {:ok, _} = convert_packages_currencies(current_user, user_currency)
    maybe_disable_sell_global_products(new_currency, current_user.organization.id)

    socket
    |> assign(:user_currency, user_currency)
    |> put_flash(:success, "Currency updated")
    |> close_modal()
    |> noreply
  end

  def handle_info(
        {:confirm_event, "allow-cash"},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: User.toggle(current_user))
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> noreply()
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
end
