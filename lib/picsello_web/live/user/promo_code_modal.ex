defmodule PicselloWeb.Live.User.Settings.PromoCodeModal do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{Onboardings, Repo, Payments, Subscriptions}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog">
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" id="modal-form" phx-target={@myself}>
        <%= hidden_inputs_for f %>
        <%= for onboarding <- inputs_for(f, :onboarding) do %>
          <%= hidden_inputs_for onboarding %>
          <%= labeled_input onboarding, :promotion_code, label: "Add a subscription promo code", type: :text_input, phx_debounce: 500, min: 0, placeholder: "enter code…", class: "mb-3" %>
        <% end %>
        <button class="w-full mt-6 btn-primary" title="test" type="submit" disabled={!@changeset.valid?} phx-disable-with="Saving&hellip;" >
          Save code
        </button>
      </.form>
      <button class="w-full mt-6 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
        Close
      </button>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"user" => user_params},
        socket
      ) do
    socket
    |> assign_changeset(user_params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"user" => %{"onboarding" => %{"promotion_code" => code}} = user_params},
        %{
          assigns: %{
            current_user: %{subscription: %{stripe_subscription_id: stripe_subscription_id}}
          }
        } = socket
      ) do
    promotion_code_id =
      case Subscriptions.maybe_get_promotion_code?(code) do
        %{stripe_promotion_code_id: stripe_promotion_code_id} ->
          stripe_promotion_code_id

        _ ->
          nil
      end

    case Payments.update_subscription(stripe_subscription_id, %{
           coupon: promotion_code_id
         }) do
      {:ok, _} ->
        build_changeset(socket, user_params, :update) |> Repo.update!()

        send(
          socket.parent_pid,
          {:close_event, %{event_name: "close_promo_code"}}
        )

        socket
        |> noreply()

      _ ->
        socket
        |> assign_changeset(user_params)
        |> put_flash(:error, "Something went wrong adding code")
        |> noreply()
    end
  end

  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, assigns)
  end

  defp build_changeset(
         %{assigns: %{current_user: user}},
         params,
         action
       ) do
    user
    |> Onboardings.user_update_promotion_code_changeset(params)
    |> Map.put(:action, action)
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end
end
