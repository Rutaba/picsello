defmodule PicselloWeb.Live.PasswordReset.New do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "onboarding"]

  alias Picsello.{Accounts, Accounts.User}

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    changeset = User.reset_password_changeset()

    socket
    |> assign_defaults(session)
    |> assign(%{
      page_title: "Reset Password",
      meta_attrs: %{
        description:
          "Forgot your password? Use this page to reset your password. Enter your email and we will get you back to building your photography business right away."
      }
    })
    |> assign(changeset: changeset, trigger_submit: false)
    |> ok()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <div class="flex flex-col items-center justify-start w-screen min-h-screen p-5 sm:justify-center bg-blue-planning-200">
        <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
          <.live_link to={Routes.page_path(@socket, :index)} >
            <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48" />
          </.live_link>
          <h1 class="mt-10 text-4xl font-bold">Forgot your password?</h1>

          <.form let={f} for={@changeset} phx-change="validate" phx-submit="submit" >
            <%= labeled_input f, :email, type: :email_input, placeholder: "email@example.com", phx_debounce: "500", wrapper_class: "mt-4" %>


            <div class="flex flex-row mt-8 sm:justify-end">
              <div class="w-full text-right sm:w-1/2 sm:pl-6">
                <%= submit "Reset Password", class: "w-full btn-primary", disabled: !@changeset.valid?, phx_disable_with: "Resetting..." %>
              </div>
            </div>
          </.form>
        </div>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.reset_password_changeset(params)
      |> Map.put(:action, :validate)

    socket |> assign(changeset: changeset) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    result =
      case Accounts.get_user_by_email(user_params["email"]) do
        %{sign_up_auth_provider: :password} = user ->
          Accounts.deliver_user_reset_password_instructions(
            user,
            &Routes.user_reset_password_url(socket, :edit, &1)
          )

        %{sign_up_auth_provider: provider} = user ->
          Accounts.deliver_provider_auth_instructions(
            user,
            Routes.auth_url(socket, :request, provider)
          )

        _ ->
          {:ok, :user_not_found}
      end

    case result do
      {:ok, _} ->
        socket
        |> put_flash(
          :info,
          "If your email is in our system, you will receive instructions to reset your password shortly."
        )
        |> redirect(to: "/")
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Unexpected error. Please try again.")
        |> noreply()
    end
  end
end
