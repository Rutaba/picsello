defmodule PicselloWeb.Live.Session.New do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "onboarding"]

  alias Picsello.{Accounts, Accounts.User}

  @impl true
  def mount(_params, session, socket) do
    changeset = User.new_session_changeset()

    socket
    |> assign_defaults(session)
    |> assign(%{
      page_title: "Log In",
      meta_attrs: %{
        description:
          "Log in to your Picsello account to start growing your photography business with our intuitive, all-in-one, photography business management software."
      }
    })
    |> assign(changeset: changeset, error_message: nil, trigger_submit: false)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-start w-screen min-h-screen p-5 sm:justify-center bg-blue-planning-200">
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <.live_link to={Routes.page_path(@socket, :index)} >
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
        </.live_link>
        <h1 class="mt-10 text-4xl font-bold">Log in</h1>

        <a href={Routes.auth_path(@socket,:request,:google)} class="flex items-center justify-center inline-block w-full my-8 text-center btn-secondary">
          <.icon name="google" width="25" height="24" class="mr-4" />

          Login with Google
        </a>

        <p class="font-bold text-center">or</p>

        <.form :let={f} for={@changeset} action={Routes.user_session_path(@socket, :create)} phx-change={:validate} phx-submit={:submit} phx-trigger-action={@trigger_submit} as={:user}>
          <%= if @error_message do %>
            <p class="text-red-sales-300"><%= @error_message %></p>
          <% end %>
          <%= hidden_input f, :trigger_submit, value: @trigger_submit %>
          <%= labeled_input f, :email, type: :email_input, placeholder: "email@example.com", phx_debounce: "500", wrapper_class: "mt-4" %>

          <%= live_component PicselloWeb.PasswordFieldComponent, f: f, id: :log_in_password, placeholder: "Enter password" %>

          <div class="flex flex-col items-center justify-between mt-8 lg:flex-row-reverse">
               <div class="flex flex-col w-full lg:flex-row-reverse lg:justify-between lg:w-1/2">
                 <%= submit "Login",
                 class: "btn-primary mb-4 sm:mb-0 flex-grow lg:ml-4",
                 disabled: !@changeset.valid?,
                 phx_disable_with: "Logging in" %>

                 <%= link "Sign up",
                 to: Routes.user_registration_path(@socket, :new),
                 class: "btn-secondary inline-block text-center flex-grow" %>
               </div>

            <div class="mt-8 mb-4 lg:mt-4">
              <%= link "Forgot your password?", to: Routes.user_reset_password_path(@socket, :new), class: "font-semibold underline text-blue-planning-300 underline-offset-1" %>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => %{"trigger_submit" => "true"}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.new_session_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.new_session_changeset(user_params)
      |> Map.put(:action, :validate)

    user =
      changeset.valid? &&
        Accounts.get_user_by_email_and_password(user_params["email"], user_params["password"])

    {:noreply,
     assign(socket,
       changeset: changeset,
       error_message: if(user, do: nil, else: "Invalid email or password"),
       trigger_submit: !!user
     )}
  end
end
