defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]
  alias Picsello.{Payments, Accounts.User, Organization, Repo}

  @impl true
  def mount(
        _params,
        _session,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(:page_title, "Settings")
    |> assign_stripe_status()
    |> assign_payment_options_changeset(%{})
    |> assign(current_user: current_user)
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
        <.card title="Payment options" class="intro-payments">
          <.form :let={f} for={@payment_options_changeset} phx-change="validate-payment-options">
            <%= inputs_for f, :payment_options, fn fp -> %>
              <%= hidden_inputs_for(fp) %>
              <div>
                <hr class="my-4" />
                <h3 class="text-lg font-bold">Accept payments outside of Stripe</h3>
                <.toggle current_user={@current_user} heading="Cash/check payments" description="Accept offline payments" input_name={:allow_cash} f={fp} />
              </div>
              <div>
                <hr  class="my-4"/>
                <h3 class="text-lg font-bold">
                  <%= if( Enum.member?([:charges_enabled, :loading], @stripe_status), do: "Accept other payments through Stripe", else: "Looks like you still need Stripe setup to use these!") %>
                </h3>
                <p class="text-sm">(Note: card is always enabled)</p>
                <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Affirm payments" description="Accept Affirm Payments" input_name={:allow_affirm} f={fp} />
                <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Afterpay payments" description="Accept afterpay payments" input_name={:allow_afterpay_clearpay} f={fp} />
                <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Klarna payments" description="Accept klarna payments" input_name={:allow_klarna} f={fp} />
                <.toggle stripe_status={@stripe_status} current_user={@current_user} heading="Cashapp payments" description="Accept cashapp payments" input_name={:allow_cashapp} f={fp} />
              </div>
            <% end %>
          </.form>
        </.card>
      </div>
    </.settings_nav>
    """
  end

  def toggle(assigns) do
    assigns =
      Enum.into(assigns, %{
        stripe_status: :charges_enabled
      })

    ~H"""
    <div class={classes("flex items-center mt-2 justify-between" , %{"opacity-50 pointer-events-none" => !Enum.member?([:charges_enabled, :loading], @stripe_status)})}>
      <div class="flex flex-col">
        <p class="font-semibold"><%= @heading %></p>
        <p class="font-normal flex text-base-250"><%= @description %></p>
      </div>
      <div class="flex justify-end items-center">
        <label class="mt-4 text-lg flex">
          <%= checkbox(@f, @input_name, class: "peer hidden", disabled: !Enum.member?([:charges_enabled, :loading], @stripe_status)) %>
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
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  def handle_event(
        "validate-payment-options",
        %{"organization" => %{"payment_options" => payment_options}},
        socket
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
        {:noreply, socket}

      {:error, changeset} ->
        {:reply, {:error, changeset}, socket}
    end
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

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(stripe_status: Payments.status(current_user) |> IO.inspect())
  end
end
