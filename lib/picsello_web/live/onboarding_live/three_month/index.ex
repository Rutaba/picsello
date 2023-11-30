defmodule PicselloWeb.OnboardingLive.ThreeMonth.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]

  alias Picsello.{
    Subscriptions,
    Subscriptions,
    Payments,
    Accounts.User.Promotions
  }

  import PicselloWeb.OnboardingLive.Shared,
    only: [
      signup_container: 1,
      signup_deal: 1,
      form_field: 1,
      save_final: 3,
      save_multi: 3,
      assign_changeset: 3,
      org_job_inputs: 1,
      most_interested_select: 0,
      country_info: 1,
      countries: 0,
      states_or_province: 1,
      field_for: 1
    ]

  @impl true
  def mount(_params, _session, socket) do
    %{value: black_friday_code} =
      Picsello.AdminGlobalSettings.get_settings_by_slug("black_friday_code")

    %{value: black_friday_timer_end} =
      Picsello.AdminGlobalSettings.get_settings_by_slug("black_friday_timer_end")

    socket
    |> assign(:main_class, "bg-gray-100")
    |> assign(:step_total, 4)
    |> assign_step()
    |> assign(:state, nil)
    |> assign(:country, nil)
    |> assign(
      :promotion_code,
      if(Subscriptions.maybe_return_promotion_code_id?(black_friday_code),
        do: black_friday_code,
        else: nil
      )
    )
    |> assign(:black_friday_timer_end, black_friday_timer_end)
    |> assign(:stripe_elements_loading, false)
    |> assign(:stripe_publishable_key, Application.get_env(:stripity_stripe, :publishable_key))
    |> assign_changeset(%{}, :mastermind)
    |> ok()
  end

  @impl true
  def handle_params(
        %{
          "payment_intent" => _,
          "redirect_status" => "succeeded",
          "state" => state,
          "country" => country
        },
        _url,
        socket
      ) do
    socket
    |> assign(:stripe_elements_loading, false)
    |> assign(:state, state)
    |> assign(:country, country)
    |> assign_step(3)
    |> noreply()
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket
    |> noreply()
  end

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: 2}} = socket), do: socket |> noreply()

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: step}} = socket) do
    socket |> assign_step(step - 1) |> assign_changeset(%{}, :mastermind) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    socket |> assign_changeset(params, :mastermind) |> noreply()
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket |> assign_changeset(%{}, :mastermind) |> noreply()
  end

  @impl true
  def handle_event("save", %{"user" => params}, %{assigns: %{step: 4}} = socket) do
    save_final(socket, params, :mastermind)
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    save(socket, params)
  end

  @impl true
  def handle_event("save", _params, %{assigns: %{step: 2}} = socket), do: noreply(socket)

  @impl true
  def handle_event(
        "stripe-elements-create",
        %{"address" => %{"value" => %{"address" => address}}} = _params,
        %{assigns: %{current_user: current_user, promotion_code: promotion_code}} = socket
      ) do
    stripe_params = %{
      customer: Subscriptions.user_customer_id(current_user, %{address: address}),
      items: [
        %{
          quantity: 1,
          price: Subscriptions.get_subscription_plan("year").stripe_price_id
        }
      ],
      coupon: Subscriptions.maybe_return_promotion_code_id?(promotion_code),
      payment_behavior: "default_incomplete",
      payment_settings: %{
        save_default_payment_method: "on_subscription"
      },
      expand: ["latest_invoice.payment_intent", "pending_setup_intent"]
    }

    case Payments.create_subscription(stripe_params) do
      {:ok, subscription} ->
        Subscriptions.handle_stripe_subscription(subscription)

        Promotions.insert_or_update_promotion(current_user, %{
          slug: promotion_code,
          state: :purchased,
          name: "Black Friday"
        })

        return =
          if is_nil(subscription.pending_setup_intent) do
            build_return(
              subscription.latest_invoice.payment_intent.client_secret,
              address,
              promotion_code,
              "payment"
            )
          else
            build_return(
              subscription.pending_setup_intent.client_secret,
              address,
              promotion_code,
              "setup"
            )
          end

        socket
        |> push_event("stripe-elements-success", return)
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Couldn't fetch your payment session. Please try again")
        |> noreply()
    end
  end

  @impl true
  def handle_event("stripe-elements-loading", _params, socket) do
    socket |> assign(:stripe_elements_loading, true) |> noreply()
  end

  @impl true
  def handle_event("stripe-elements-error", _params, socket) do
    socket
    |> assign(:stripe_elements_loading, false)
    |> put_flash(:error, "Couldn't fetch your payment session. Please try again")
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"onboarding-step-#{@step}"} class={classes("" , %{"pointer-events-none" => @stripe_elements_loading})}>
        <.step f={f} {assigns} />
      </.form>
    """
  end

  defp step(%{step: 2} = assigns) do
    ~H"""
      <.signup_container {assigns} show_logout?={true} left_classes="p-8 bg-purple-marketing-300 text-white order-2 sm:order-1">
        <h2 class="text-3xl md:text-4xl font-bold text-center mb-8">THREE MONTH Picsello is here to help you achieve success on your terms</h2>
        <blockqoute class="max-w-lg mt-auto mx-auto py-8 lg:py-12">
          <p class="mb-4 text-white border-solid border-l-4 border-white pl-4">
            "Jane has been a wonderful mentor! With her help I’ve learned the importance of believing in myself and my work. She has taught me that it is imperative to be profitable at every stage of my photography journey to ensure I’m set up for lasting success. Jane has also given me the tools I need to make sure I’m charging enough to be profitable. She is always there to answer my questions and cheer me on. Jane has played a key role in my growth as a photographer and business owner! I wouldn’t be where I am without her!”
          </p>
          <div class="flex items-center gap-4">
            <img src={Routes.static_path(@socket, "/images/mastermind-quote.png")} loading="lazy" alt="Logo for Jess Allen Photography" class="w-12 h-12 object-contain" />
            <cite class="normal not-italic text-white"><span class="block font-bold not-italic">Jess Allen</span>
              jessallenphotography.com</cite>
          </div>
        </blockqoute>
        <div class="flex justify-center mt-12">
          <img src={Routes.static_path(@socket, "/images/mastermind-logo.png")} loading="lazy" alt="Picsello Mastermind logo" class="h-16" />
        </div>
        <%= if @stripe_elements_loading do %>
          <div class="fixed bg-base-300/75 backdrop-blur-md pointer-events-none w-full h-full z-50 top-0 left-0 flex items-center justify-center">
            <.icon class="animate-spin w-8 h-8 mr-2 text-white" name="loader"/>
            <p class="font-bold">Processing payment…</p>
          </div>
        <% end %>
        <:right_panel>
          <.signup_deal original_price={Money.new(35000, :USD)} price={Money.new(20000, :USD)} expires_at={@black_friday_timer_end} />
          <p class="text-md text-gray-400 italic text-center mt-2">Your card will be charged the discounted annual subscription price</p>
          <div
            phx-update="ignore"
            class="my-6"
            phx-hook="StripeElements"
            id="stripe-elements"
            data-publishable-key={@stripe_publishable_key}
            data-name={@current_user.name}
            data-email={@current_user.email}
            data-return-url={"#{PicselloWeb.Router.Helpers.page_url(PicselloWeb.Endpoint, :index)}#{Routes.onboarding_three_month_path(@socket, :index)}"}
          >
            <div id="address-element"></div>
            <div id="payment-element" class="mt-2"></div>
          </div>
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step(%{step: 3} = assigns) do
    assigns = assign(assigns, input_class: "p-4")

    ~H"""
      <.signup_container {assigns} show_logout?={true} left_classes="p-8 bg-purple-marketing-300 text-white order-2 sm:order-1">
        <div class="flex justify-center mt-12">
          <img src={Routes.static_path(@socket, "/images/mastermind-clientbooking.png")} loading="lazy" alt="Picsello Client booking feature" class="max-w-full" />
        </div>
        <blockqoute class="max-w-lg mt-auto mx-auto py-8 lg:py-12">
          THREE MONTH
          <p class="mb-4 text-white border-solid border-l-4 border-white pl-4">
            “I love the way that Picsello flows and so easy to use! All the information I need is easily accessible and well organized. Putting together a proposal for a client is so simple and takes only a few clicks before it's ready to send off for signing and payment.”
          </p>
          <div class="flex items-center gap-4">
            <img src={Routes.static_path(@socket, "/images/mastermind-quote2.png")} loading="lazy" alt="Logo for Emma Thurgood" class="w-12 h-12 object-contain" />
            <cite class="normal not-italic text-white"><span class="block font-bold not-italic">Emma Thurgood</span>
            emmathurgood.com</cite>
          </div>
        </blockqoute>
        <:right_panel>
          <%= for org <- inputs_for(@f, :organization) do %>
            <%= hidden_inputs_for org %>
            <.form_field label="What’s the name of your photography business?" error={:name} prefix="Photography business name" f={org} mt={0} >
              <%= input org, :name, phx_debounce: "500", placeholder: "Jack Nimble Photography", class: @input_class %>
              <p class="italic text-sm text-gray-400 mt-2"><%= PicselloWeb.Router.Helpers.profile_url(PicselloWeb.Endpoint, :index, input_value(org, :slug)) %></p>
            </.form_field>
          <% end %>
          <%= for onboarding <- inputs_for(@f, :onboarding) do %>
            <%= hidden_input onboarding, :promotion_code, value: @promotion_code %>
            <.form_field label="Are you a full-time or part-time photographer?" error={:schedule} f={onboarding} >
              <%= select onboarding, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select #{@input_class}" %>
            </.form_field>

            <.form_field label="How many years have you been a photographer?" error={:photographer_years} f={onboarding} >
              <%= input onboarding, :photographer_years, type: :number_input, phx_debounce: 500, min: 0, placeholder: "e.g. 0, 1, 2, etc.", class: @input_class %>
            </.form_field>

            <%= hidden_input onboarding, :welcome_count, value: 0 %>

            <.form_field
              label="What are you most interested in using Picsello for?"
              error={:interested_in}
              prefix="Select one"
              f={onboarding}
            >
              <%= select(onboarding, :interested_in, [{"select one", nil}] ++ most_interested_select(),
                class: "select #{@input_class} truncate pr-8"
              ) %>
            </.form_field>

            <%= if is_nil(@country) || is_nil(@state) do %>
              <% info = country_info(input_value(onboarding, :country)) %>
              <div class={classes("grid gap-4 mb-8", %{"sm:grid-cols-2" => Map.has_key?(info, :state_label)})}>
                <.form_field label="What’s your country?" error={:country} f={onboarding}>
                  <%= select(onboarding, :country, [{"United States", :US}] ++ countries(),
                    class: "select #{@input_class}"
                  ) %>
                </.form_field>

                <%= if Map.has_key?(info, :state_label) do %>
                  <.form_field label={info.state_label} error={:state} f={onboarding}>
                    <%= select(
                      onboarding,
                      field_for(input_value(onboarding, :country)),
                      [{"select one", nil}] ++ states_or_province(input_value(onboarding, :country)),
                      class: "select #{@input_class}"
                    ) %>
                  </.form_field>
                <% end %>
              </div>
            <% else %>
              <%= if @country == "CA" do %>
                <%= hidden_input onboarding, :province, value: @state %>
              <% else %>
                <%= hidden_input onboarding, :state, value: @state %>
              <% end %>
              <%= hidden_input onboarding, :country, value: @country %>
            <% end %>

          <% end %>
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step(%{step: 4} = assigns) do
    ~H"""
      <.signup_container {assigns} show_logout?={true} left_classes="p-8 pb-0 pr-0 bg-purple-marketing-300 text-white order-2 sm:order-1">
        <h2 class="text-3xl md:text-4xl font-bold text-center mb-8">Your <span class="underline underline-offset-1 text-decoration-blue-planning-300">all-in-one</span> photography business software with coaching included.</h2>
        <img src={Routes.static_path(@socket, "/images/mastermind-dashboard.png")} loading="lazy" alt="Picsello Client booking feature" />
        <:right_panel>
          <.org_job_inputs {assigns} />
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step_footer(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-5 sm:justify-end sm:mt-auto gap-4">
      <%= if @step > 3 do %>
        <button type="button" phx-click="previous" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
          Back
        </button>
      <% end %>
      <button type="submit" phx-disable-with="Saving…" disabled={if @step === 2 do @stripe_elements_loading else !@changeset.valid? || @stripe_elements_loading end} id={if @step === 2 do "payment-element-submit" end} class="flex-grow px-6 btn-primary sm:px-8">
        <%= if @stripe_elements_loading do %>
          Saving…
        <% else %>
          <%= if @step == 4, do: "Finish", else: "Next" %>
        <% end %>
      </button>
    </div>
    """
  end

  defp assign_step(%{assigns: %{current_user: %{stripe_customer_id: nil}}} = socket) do
    assign_step(socket, 2)
  end

  defp assign_step(%{assigns: %{current_user: %{onboarding: onboarding}}} = socket) do
    if is_nil(onboarding.photographer_years) &&
         is_nil(onboarding.schedule),
       do: assign_step(socket, 3),
       else: assign_step(socket, 4)
  end

  defp assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      step_title: "Get the deal",
      page_title: "Onboarding Step 2"
    )
  end

  defp assign_step(socket, 3) do
    socket
    |> assign(
      step: 3,
      step_title: "Create your Picsello profile",
      page_title: "Onboarding Step 3"
    )
  end

  defp assign_step(socket, 4) do
    socket
    |> assign(
      step: 4,
      step_title: "Customize your business",
      page_title: "Onboarding Step 4"
    )
  end

  defp save(%{assigns: %{step: step}} = socket, params, data \\ :skip) do
    save_multi(socket, params, data)
    |> then(fn
      {:ok, %{user: user}} ->
        socket
        |> assign(current_user: user)
        |> assign_step(step + 1)
        |> assign_changeset(%{}, :mastermind)

      {:error, reason} ->
        socket |> assign(changeset: reason)
    end)
    |> noreply()
  end

  defp build_return(client_secret, address, promotion_code, type) do
    %{
      type: type,
      client_secret: client_secret,
      promotion_code: promotion_code,
      state:
        if Map.get(address, "country") == "US" do
          Map.get(address, "state")
        else
          "Non-US"
        end,
      country: Map.get(address, "country")
    }
  end
end
