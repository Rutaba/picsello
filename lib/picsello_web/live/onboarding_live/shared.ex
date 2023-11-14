defmodule PicselloWeb.OnboardingLive.Shared do
  @moduledoc false
  require Logger

  use Phoenix.Component
  use Phoenix.HTML

  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{Repo, Onboardings, Subscriptions, UserCurrency}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Ecto.Multi

  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  import Picsello.Zapier.User, only: [user_trial_created_webhook: 1]
  import PicselloWeb.FormHelpers, only: [error_tag: 3]

  import Phoenix.LiveView, only: [push_redirect: 2]

  import PicselloWeb.LiveHelpers,
    only: [
      icon: 1,
      noreply: 1,
      job_type_option: 1
    ]

  def signup_deal(assigns) do
    assigns =
      Enum.into(assigns, %{
        original_price: nil,
        price: nil,
        expires_at: nil,
        note: nil
      })

    ~H"""
      <div class="bg-white" phx-update="ignore" id="timer">
        <div class="bg-base-200 p-8">
          <h3 class="text-4xl text-purple-marketing-300 flex justify-center gap-2">
            <%= if @original_price do %>
              <strike class="font-bold"><%= @original_price %></strike>
            <% end %>
            <%= @price %>
          </h3>
          <%= if @note do %>
            <p class="text-md font-light text-center mt-4 text-purple-marketing-300"><%= @note %></p>
          <% end %>
        </div>
        <%= if @expires_at do %>
          <div class="border flex justify-center p-2 text-purple-marketing-300 font-light tracking-wider text-lg" id="bf-timer" phx-hook="Timer" data-end={@expires_at}></div>
        <% end %>
      </div>
    """
  end

  def signup_container(assigns) do
    assigns =
      Enum.into(assigns, %{
        left_classes: "p-8 bg-purple-marketing-300 text-white",
        show_logout?: false,
        right_classes: "p-8",
        step: nil,
        step_total: nil,
        step_title: nil
      })

    ~H"""
      <div class="min-h-screen md:max-w-6xl container mx-auto">
        <div class="py-8 flex items-center justify-center">
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
        </div>
        <div class="grid sm:grid-cols-2 bg-white rounded-lg">
          <div class={"sm:rounded-l-lg #{@left_classes}"}>
            <%= render_slot(@inner_block) %>
          </div>
          <div class={"#{@right_classes} order-1 sm:order-2 flex flex-col"}>
            <%= if @step && @step_total do %>
              <div class="text-sm font-bold text-gray-500">
                <%= @step %> / <%= @step_total %>
              </div>
            <% end %>
            <%= if @step_title do %>
              <h1 class="text-3xl font-bold sm:leading-tight mt-2 mb-4"><%= @step_title %></h1>
            <% end %>
            <%= render_slot(@right_panel) %>
          </div>
        </div>
        <%= if @show_logout? do %>
          <div class="flex items-center justify-center my-8">
            <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete) %>
          </div>
        <% end %>
      </div>
    """
  end

  def update_user_client_trial(socket, current_user) do
    %{
      list_ids: SendgridClient.get_all_client_list_env(),
      clients: [
        %{
          email: current_user.email,
          state_province_region: current_user.onboarding.state,
          custom_fields: %{
            w3_T: current_user.organization.name,
            w1_T: "trial"
          }
        }
      ]
    }
    |> SendgridClient.add_clients()

    user_trial_created_webhook(%{email: current_user.email})

    socket
  end

  def form_field(assigns) do
    assigns = Enum.into(assigns, %{error: nil, prefix: nil, class: "py-2", mt: 4})

    ~H"""
    <label class={"flex flex-col mt-#{@mt}"}>
      <p class={"#{@class} font-extrabold"}><%= @label %></p>
      <%= render_slot(@inner_block) %>

      <%= if @error do %>
        <%= error_tag @f, @error, prefix: @prefix, class: "text-red-sales-300 text-sm" %>
      <% end %>
    </label>
    """
  end

  def org_job_inputs(assigns) do
    ~H"""
    <%= for o <- inputs_for(@f, :organization) do %>
      <%= hidden_inputs_for o %>

        <div class="flex flex-col pb-1">
          <p class="py-2 font-extrabold">
            What’s your photography speciality?
            <i class="italic font-light">(Select one or more)</i>
          </p>

          <div data-rewardful-email={@current_user.email} id="rewardful-email"></div>

          <div class="mt-2 grid grid-cols-2 gap-3 sm:gap-5">
            <%= for jt <- inputs_for(o, :organization_job_types) |> Enum.sort_by(&(&1.data.job_type)) do %>
              <% input_name = input_name(jt, :job_type) %>
              <%= hidden_inputs_for(jt) %>
              <%= if jt.data.job_type != "global" do %>
                <% checked = jt |> current() |> Map.get(:show_on_business?) %>
                <.job_type_option type="checkbox" name={input_name} form={jt} job_type={jt |> current() |> Map.get(:job_type)} checked={checked} />
              <% else %>
                <input class="hidden" type="checkbox" name={input_name} value={jt |> current() |> Map.get(:job_type)} checked={true} />
              <% end %>
              <%= hidden_input jt, :type, value: jt |> current() |> Map.get(:job_type) %>
            <% end %>
          </div>
          <div class="flex flex-row">
            <div class="flex items-center justify-center w-7 h-7 ml-1 mr-3 mt-2 rounded-full flex-shrink-0 bg-blue-planning-300 text-white">
              <.icon name="global" class="fill-current" width="14" height="14" />
            </div>
            <div class="flex flex-col">
              <p class="pt-2 font-bold">
                Not seeing yours here?
              </p>
              <p class="text-gray-400 font-normal">
                All Picsello accounts include an <strong>Global</strong> photography speciality in case yours isn’t listed here.
              </p>
            </div>
          </div>
        </div>
    <% end %>
    """
  end

  def save_final(socket, params, onboarding_type \\ nil, data \\ :skip) do
    IO.inspect(params, label: "checkparams")
    # Logger.info(
    #   "Check params for create: #{params}"
    # )
    params = update_job_params(params)

    Multi.new()
    |> Multi.put(:data, data)
    |> Multi.update(:user, build_changeset(socket, params, onboarding_type))
    |> Multi.insert(:global_gallery_settings, fn %{user: %{organization: organization}} ->
      GSGallery.price_changeset(%GSGallery{}, %{organization_id: organization.id})
    end)
    |> Multi.insert(
      :user_currencies,
      fn %{user: %{organization: organization}} ->
        UserCurrency.currency_changeset(
          %UserCurrency{},
          %{
            organization_id: organization.id,
            currency: "USD"
          }
        )
      end,
      conflict_target: [:organization_id],
      on_conflict: :nothing
    )
    |> maybe_insert_subscription(socket, onboarding_type)
    |> Multi.run(:user_automations, fn _repo, %{user: %{organization: organization}} ->
      case Mix.Tasks.ImportEmailPresets.assign_default_presets_new_user(organization.id) do
        {_, nil} ->
          {:ok, nil}

        {:error, _} ->
          {:error, "Couldn't assign default email presets"}
      end
    end)
    |> Multi.run(:user_temp_navbar, fn _repo, %{user: user} ->
      # temporarily add enable for all net new users
      # we are doing this to A/B cohort test the new navbar
      # and see if it helps with retention/ease of use
      if FunWithFlags.enabled?(:photo_lab) do
        FunWithFlags.enable(:sidebar_navigation, for_actor: user)
      end

      {:ok, nil}
    end)
    |> Multi.run(:user_final, fn _repo, %{user: user} ->
      with _ <- Onboardings.complete!(user) do
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{user: user}} ->
        socket
        |> assign(current_user: user)
        |> update_user_client_trial(user)
        |> push_redirect(to: Routes.home_path(socket, :index), replace: true)

      {:error, reason} ->
        socket |> assign(changeset: reason)
    end)
    |> noreply()
  end

  def save_multi(socket, params, data) do
    Multi.new()
    |> Multi.put(:data, data)
    |> Multi.update(:user, build_changeset(socket, params))
    |> Repo.transaction()
  end

  defp maybe_insert_subscription(multi, socket, onboarding_type) do
    if is_nil(onboarding_type) do
      multi
      |> Multi.run(:subscription, fn _repo, %{user: user} ->
        with :ok <-
               Subscriptions.subscription_base(user, "month",
                 trial_days: socket.assigns.subscription_plan_metadata.trial_length
               )
               |> Picsello.Subscriptions.handle_stripe_subscription() do
          {:ok, nil}
        end
      end)
    else
      # subscription is being added via stripe elements
      multi
    end
  end

  defp update_job_params(params) do
    {key, _value} =
      Enum.find(params["organization"]["organization_job_types"], fn {_key, value} ->
        Map.get(value, "type") == "mini"
      end)

    update_in(
      params,
      ["organization", "organization_job_types", key],
      &Map.put(&1, "job_type", "mini")
    )
  end

  def build_changeset(
        %{assigns: %{current_user: user, step: step}},
        params,
        onboarding_type \\ nil,
        action \\ nil
      ) do
    user
    |> Onboardings.changeset(params, step: step, onboarding_type: onboarding_type)
    |> Map.put(:action, action)
  end

  def assign_changeset(socket, params \\ %{}, onboarding_type \\ nil) do
    socket
    |> assign(changeset: build_changeset(socket, params, onboarding_type, :validate))
  end

  def most_interested_select() do
    [
      {"Booking Events", :booking_events},
      {"All-in-one platform", :all_in_one_platform},
      {"Business mastermind, education and community",
       :business_mastermind_education_and_community},
      {"Smart Profit Calculator™ and help with pricing",
       :smart_profit_calculator_and_help_with_pricing},
      {"Mobile-first design", :mobile_first_design},
      {"Unlimited client photo galleries with self-serve digital image and print product orders",
       :unlimited},
      {"Other", :other}
    ]
  end

  def country_info("US"), do: %{state_label: "What’s your state?"}
  def country_info("CA"), do: %{state_label: "What’s your province?"}
  def country_info(nil), do: %{state_label: "What's your state?"}
  def country_info(_), do: %{}

  def countries() do
    Picsello.Country.all() |> Enum.reject(&(&1.code == "US")) |> Enum.map(&{&1.name, &1.code})
  end

  def states_or_province("CA"), do: canadian_provinces()
  def states_or_province(_), do: states()

  def field_for("CA"), do: :province
  def field_for(_), do: :state

  def canadian_provinces() do
    [
      {"Alberta", :alberta},
      {"Atlantic Canada", :atlantic_canada},
      {"British Columbia", :british_columbia},
      {"Manitoba", :manitoba},
      {"New Brunswick", :new_brunswick},
      {"Newfoundland and Labrador", :newfoundland_and_labrador},
      {"Northwest Territories", :northwest_territories},
      {"Nova Scotia", :nova_scotia},
      {"Nunavut", :nunavut},
      {"Ontario", :ontario},
      {"Prince Edward Island", :prince_edward_island},
      {"Quebec", :quebec},
      {"Saskatchewan", :saskatchewan},
      {"Yukon", :yukon}
    ]
  end

  defdelegate states(), to: Onboardings, as: :state_options
end
