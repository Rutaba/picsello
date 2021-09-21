defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]
  alias Picsello.{Job, Repo, Accounts.User}
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

  @imple true
  def handle_event("previous", %{}, %{assigns: %{step: step}} = socket) do
    socket |> assign_step(step - 1) |> noreply()
  end

  def handle_event("validate", %{"user" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  def handle_event("save", %{"user" => params}, %{assigns: %{step: step}} = socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, user} -> socket |> assign(current_user: user) |> assign_step(step + 1) |> noreply()
      {:error, _message} -> socket |> noreply()
    end
  end

  @imple true
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
        <%= labeled_input o, :name, label: "What would you like to name your business?", phx_debounce: "500", placeholder: "Jack Nimble Photography", wrapper_class: "mt-4" %>
      <% end %>

      <%= for o <- inputs_for(@f, :onboarding) do %>
        <%= hidden_inputs_for o %>
        <%= labeled_input o, :website, label: "What is your website address? (No worries if you don’t have one)", placeholder: "www.mystudio.com", phx_debounce: "500", wrapper_class: "mt-4" %>
        <%= labeled_input o, :no_website, type: :checkbox, label: "I don't have one", wrapper_class: "mt-4", class: "checkbox" %>
        <%= labeled_input o, :phone, type: :telephone_input, label: "What is your phone number?", placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500", wrapper_class: "mt-4" %>
        <%= labeled_select o, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, label: "Are you full-time or part-time?", wrapper_class: "mt-4" %>
      <% end %>
    """
  end

  def step(%{step: 3} = assigns) do
    ~H"""
      <h1>this is step 3!</h1>
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

  def build_changeset(%{assigns: %{current_user: user}} = socket, params \\ %{}, action \\ nil) do
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
        <div class="flex justify-between">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48" />
          <ul class="flex items-center">
            <%= for step <- 1..5 do %>
              <li>
                <a phx-click="previous" title={"onboarding step #{step}"} href={"##{step}"} class={"#{ if step == @step, do: @color_class, else: "bg-gray-200" } block w-3 h-3 rounded-full ml-1.5"}>
                </a>
              </li>
            <% end %>
          </ul>
        </div>
        <h1 class="text-3xl font-bold sm:text-4xl mt-7 sm:mt-11"><%= @title %></h1>
        <h2 class="mt-2 sm:mt-5 sm:text-2xl"><%= @subtitle %></h2>

        <%= render_block(@inner_block) %>
       </div>
    </div>
    """
  end
end
