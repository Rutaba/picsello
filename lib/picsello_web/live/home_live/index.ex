defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  require Logger

  import PicselloWeb.HomeLive.Shared

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(:page_title, "Work Hub")
    |> assign(:stripe_subscription_status, nil)
    |> assign_counts()
    |> assign_attention_items()
    |> subscribe_inbound_messages()
    |> maybe_show_success_subscription(params)
    |> ok()
  end

  @impl true
  defdelegate handle_params(name, params, socket), to: PicselloWeb.HomeLive.Shared

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.HomeLive.Shared

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.HomeLive.Shared
end
