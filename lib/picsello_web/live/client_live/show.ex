defmodule PicselloWeb.Live.ClientLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.ClientLive.{Shared, Index}
  import PicselloWeb.JobLive.Shared, only: [card: 1]

  alias Picsello.{Clients, Client}
  alias PicselloWeb.Live.ClientLive

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket
    |> get_client(id)
    |> assign(:job_types, Picsello.JobType.all())
    |> assign(:tags_changeset, ClientLive.Index.tag_default_changeset(%{}))
    |> ok()
  end

  @impl true
  def handle_params(params, _, socket) do
    socket
    |> is_mobile(params)
    |> noreply()
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: ClientLive.Index

  def handle_info({:update, %{client: client}}, socket) do
    socket
    |> assign(:client, client)
    |> put_flash(:success, "Client updated successfully")
    |> noreply()
  end

  @impl true
  defdelegate handle_info(message, socket), to: ClientLive.Index

  defp get_client(%{assigns: %{current_user: user}} = socket, id) do
    case Clients.get_client(id, user) do
      %Client{} = client ->
        socket |> assign(:client, client)

      nil ->
        socket |> redirect(to: "/clients")
    end
  end
end
