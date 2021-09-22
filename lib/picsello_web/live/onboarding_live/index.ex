defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]
  alias Picsello.{Repo, Accounts.User}
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
  def render(assigns) do
    ~H"""
      <.container step={@step} color_class={@color_class} title={@step_title} subtitle={@subtitle}>
        <.form let={f} for={@changeset} phx-change="validate" phx-submit="save">
          <.step f={f} step={@step} />

          <div class="flex justify-between mt-5 sm:justify-end sm:mt-9">
            <button type="submit" phx-disable-with="Skipping..." disabled={!@changeset.valid?} class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">Skip</button>
            <button type="submit" phx-disable-with="Saving..." disabled={!@changeset.valid?} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">Next</button>
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

  def assign_step(socket, _), do: push_redirect(socket, to: Routes.home_path(socket, :index))

  def build_changeset(%{assigns: %{current_user: user}}, params \\ %{}, action \\ nil) do
    user |> User.onboarding_changeset(params) |> Map.put(:action, action)
  end

  def assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  def container(assigns) do
    ~H"""
    <div class={"flex flex-col items-center justify-center w-screen min-h-screen p-5 #{@color_class}"}>
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <div class="flex items-end justify-between">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48" />
          <ul class="flex items-center">
            <%= for step <- 1..5 do %>
              <li>
                <a
                phx-click="previous"
                title={"onboarding step #{step}"}
                href={"##{step}"}
                class={"#{ if step == @step, do: @color_class, else: "bg-gray-200" } block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3"}>
                </a>
              </li>
            <% end %>
          </ul>
        </div>
        <h1 class="text-3xl font-bold sm:text-5xl mt-7 sm:leading-tight sm:mt-11"><%= @title %></h1>
        <h2 class="mt-2 sm:mb-7 sm:mt-5 sm:text-2xl"><%= @subtitle %></h2>

        <%= render_block(@inner_block) %>
       </div>
    </div>
    """
  end
end
