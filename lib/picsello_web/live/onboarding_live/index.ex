defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]
  alias Picsello.{Repo, Accounts.User, JobType}
  require Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_step(2)
    |> then(fn %{assigns: %{current_user: user}} = socket ->
      socket |> assign(current_user: user |> Repo.preload(:organization))
    end)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: 2}} = socket), do: socket |> noreply()

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: step}} = socket) do
    socket |> assign_step(step - 1) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"user" => params}, %{assigns: %{step: step}} = socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, user} -> socket |> assign(current_user: user) |> assign_step(step + 1) |> noreply()
      {:error, _message} -> socket |> noreply()
    end
  end

  @impl true
  def handle_event("skip", _params, %{assigns: %{changeset: changeset, step: step}} = socket) do
    case socket
         |> build_changeset(changes_without_errors(changeset))
         |> Repo.update() do
      {:ok, user} -> socket |> assign(current_user: user) |> assign_step(step + 1) |> noreply()
      {:error, _} -> socket |> assign_step(step + 1) |> noreply()
    end
  end

  defp changes_without_errors(%{errors: errors, changes: changes} = changeset) do
    acc = changeset |> Ecto.Changeset.apply_changes() |> Map.take([:id])
    error_fields = Keyword.keys(errors)

    for {field, value} <- changes, reduce: acc do
      acc ->
        cond do
          is_struct(value, Ecto.Changeset) ->
            Map.put(acc, field, changes_without_errors(value))

          Enum.member?(error_fields, field) ->
            acc

          true ->
            Map.put(acc, field, value)
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.container step={@step} color_class={@color_class} title={@step_title} subtitle={@subtitle}>
        <.form let={f} for={@changeset} phx-change="validate" phx-submit="save">
          <.step f={f} step={@step} />

          <div class="flex justify-between mt-5 sm:justify-end sm:mt-9">
            <button type="button" phx-click="skip" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
              <%= if @step == 5, do: "Skip & Finish", else: "Skip" %>
            </button>
            <button type="submit" phx-disable-with="Saving..." disabled={!@changeset.valid?} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">
              <%= if @step == 5, do: "Finish", else: "Next" %>
            </button>
          </div>
        </.form>
      </.container>
    """
  end

  def step(%{step: 2} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :organization) do %>
        <%= hidden_inputs_for o %>

        <label class="flex flex-col">
          <p class="py-2 font-extrabold">What would you like to name your business?</p>

          <%= input o, :name, phx_debounce: "500", placeholder: "Jack Nimble Photography", class: "p-4" %>
          <%= error_tag o, :name, class: "text-red-invalid text-sm" %>
        </label>
      <% end %>

      <%= for o <- inputs_for(@f, :onboarding) do %>
        <%= hidden_inputs_for o %>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">What is your website address? <i class="italic font-light">(No worries if you don’t have one)</i></p>

          <div class="relative flex flex-col">
            <%= input o, :website,
                phx_debounce: "500",
              disabled: input_value(o, :no_website) == true,
                placeholder: "www.mystudio.com",
                class: "p-4 sm:pr-48" %>
            <%= error_tag o, :website, class: "text-red-invalid text-sm" %>

            <label id="clear-website" phx-hook="ClearInput" data-input-name="website" class="flex items-center py-2 pl-2 pr-3 mt-2 bg-gray-200 rounded sm:absolute top-2 right-2 sm:mt-0">
              <%= checkbox o, :no_website, class: "w-5 h-5 checkbox" %>

              <p class="ml-2">I don't have one</p>
            </label>
          </div>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">What is your phone number?</p>

          <%= input o, :phone, type: :telephone_input, phx_debounce: 500, placeholder: "(555) 555-5555", phx_hook: "Phone", class: "p-4" %>
          <%= error_tag o, :phone, class: "text-red-invalid text-sm" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">Are you full-time or part-time?</p>

          <%= select o, :schedule, %{"" => nil, "Full-time" => :full_time, "Part-time" => :part_time}, class: "select p-4" %>
        </label>
      <% end %>
    """
  end

  def step(%{step: 3} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :onboarding) do %>
        <label class="flex flex-col">
          <p class="py-2 font-extrabold">Color <i class="italic font-light">(Used to customize your invoices, emails, and profile)</i></p>
          <ul class="mt-2 grid grid-cols-4 gap-5 sm:gap-3 sm:grid-cols-8">
            <%= for(color <- colors()) do %>
              <li class="aspect-h-1 aspect-w-1">
                <label>
                  <%= radio_button o, :color, color, class: "hidden" %>
                  <div class={classes(
                    "flex cursor-pointer items-center hover:border-black justify-center w-full h-full border rounded", %{
                    "border-black" => input_value(o, :color) == color,
                    "hover:border-opacity-40" => input_value(o, :color) != color
                  })}>
                    <div class="w-4/5 rounded h-4/5" style={"background-color: #{color}"}></div>
                  </div>
                </label>
              </li>
            <% end %>
          </ul>
        </label>
      <% end %>
    """
  end

  def step(%{step: 4} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :onboarding) do %>
        <% input_name = input_name(o,:job_types) <> "[]" %>
        <div class="flex flex-col pb-1">
          <p class="py-2 font-extrabold">
            What types of photography do you shoot?
            <i class="italic font-light">(Select one or more)</i>
          </p>

          <input type="hidden" name={input_name} value="">

          <div class="mt-2 grid grid-cols-2 gap-3 sm:gap-5">
            <%= for(job_type <- job_types()) do %>
              <.job_type_option name={input_name} job_type={job_type} checked={input_value(o, :job_types) |> Enum.member?(job_type)} />
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end

  def step(%{step: 5} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :onboarding) do %>
        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">How many years have you been a photographer?</p>

          <%= input o, :photographer_years, type: :number_input, phx_debounce: 500, placeholder: "22", class: "p-4" %>
          <%= error_tag o, :photographer_years, class: "text-red-invalid text-sm" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">Have you used business software for photography before?</p>

          <%= select o, :used_software_before, %{"No" => false, "Yes" => true}, class: "select p-4" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class={classes("py-2 font-extrabold", %{"text-gray-400" => !input_value(o, :used_software_before) })}>
            Are you switching from a different business or studio management tool?
          </p>

          <%= select o, :switching_from_software, software_options(), disabled: !input_value(o, :used_software_before), class: "select p-4" %>
        </label>
      <% end %>
    """
  end

  def software_options(),
    do: [
      {"Select One", ""},
      {"Studio Ninja", :studio_ninja},
      {"ShootProof", :shoot_proof},
      {"Other", :other}
    ]

  def job_type_option(assigns) do
    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:bg-blue-light-primary hover:bg-opacity-60 cursor-pointer font-semibold text-sm leading-tight sm:text-base",
        %{"border-blue-primary bg-blue-light-primary" => @checked}
      )}>
        <input class="hidden" type="checkbox" name={@name} value={@job_type} checked={@checked} />

        <div class={classes(
          "flex items-center justify-center w-7 h-7 ml-1 mr-3 bg-gray-200 rounded-full flex-shrink-0",
          %{"bg-blue-primary text-white" => @checked}
        )}>
          <.icon name={@job_type} class="fill-current" width="14" height="14" />
        </div>

        <%= dyn_gettext @job_type %>
      </label>
    """
  end

  def assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      color_class: "bg-orange-onboarding-second",
      step_title: "Tell us more about yourself",
      subtitle: "We need a little more info to get your account ready!",
      page_title: "Onboarding Step 2"
    )
  end

  def assign_step(socket, 3) do
    socket
    |> assign(
      step: 3,
      color_class: "bg-green-onboarding-third",
      step_title: "Customize your business",
      subtitle: "We need a little more info to get your account ready!",
      page_title: "Onboarding Step 3"
    )
  end

  def assign_step(socket, 4) do
    socket
    |> assign(
      step: 4,
      color_class: "bg-blue-onboarding-fourth",
      step_title: "Customize your business",
      subtitle: "We need a little more info to get your account ready!",
      page_title: "Onboarding Step 4"
    )
  end

  def assign_step(socket, 5) do
    socket
    |> assign(
      step: 5,
      color_class: "bg-blue-onboarding-first",
      step_title: "Optional questions",
      subtitle:
        "While these final few questions are optional, answering them will help us understand and serve each of our customers better.",
      page_title: "Onboarding Step 5"
    )
  end

  def assign_step(%{assigns: %{current_user: current_user}} = socket, _) do
    socket
    |> assign(
      current_user: current_user |> User.complete_onboarding_changeset() |> Repo.update!()
    )
    |> push_redirect(to: Routes.home_path(socket, :index), replace: true)
  end

  def build_changeset(%{assigns: %{current_user: user}}, params \\ %{}, action \\ nil) do
    user |> User.onboarding_changeset(params) |> Map.put(:action, action)
  end

  def assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  def container(assigns) do
    ~H"""
    <div class={classes(["flex flex-col items-center justify-center w-screen min-h-screen p-5", @color_class])}>
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <div class="flex items-end justify-between sm:items-center">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48" />

          <a title="previous" href="#" phx-click="previous" class="cursor-pointer sm:py-2">
            <ul class="flex items-center">
              <%= for step <- 1..5 do %>
                <li class={classes(
                  "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
                  %{ @color_class => step == @step, "bg-gray-200" => step != @step }
                )}>
                </li>
              <% end %>
            </ul>
          </a>
        </div>

        <h1 class="text-3xl font-bold sm:text-5xl mt-7 sm:leading-tight sm:mt-11"><%= @title %></h1>
        <h2 class="mt-2 mb-2 sm:mb-7 sm:mt-5 sm:text-2xl"><%= @subtitle %></h2>
        <%= render_block(@inner_block) %>
       </div>
    </div>
    """
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate colors(), to: User.Onboarding
end
