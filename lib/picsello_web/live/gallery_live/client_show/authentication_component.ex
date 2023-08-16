defmodule PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries
  import Picsello.Profiles, only: [logo_url: 1]

  def mount(socket) do
    socket
    |> assign(:password_is_correct, true)
    |> assign(:submit, false)
    |> assign(:session_token, nil)
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_password_change()
    |> ok()
  end

  def handle_event("change", %{"login" => params}, socket) do
    socket
    |> assign_password_change(params)
    |> noreply()
  end

  def handle_event(
        "check",
        %{"login" => %{"email" => email, "password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    valid_email? = String.length(email) > 0 && Regex.match?(~r/^[^\s]+@[^\s]+.[^\s]+$/, email)

    if valid_email? do
      gallery
      |> Galleries.build_gallery_session_token(password, email)
      |> case do
        {:ok, token} ->
          update_emails_map(email, gallery)
          assign(socket, submit: true, session_token: token)

        _ ->
          assign(socket, password_is_correct: false)
      end
    else
      assign(socket, password_is_correct: false, submit: false)
    end
    |> noreply()
  end

  def maybe_show_logo?(%{gallery: %{job: %{client: %{organization: organization}}}} = assigns) do
    assigns = Map.put(assigns, :organization, organization)

    ~H"""
      <%= case logo_url(@organization) do %>
        <% nil -> %> <h1 class="pt-3 text-3xl font-light font-client text-base-300 mb-2 text-center"><%= @organization.name %></h1>
        <% url -> %> <img class="h-20 mx-auto" src={url} />
      <% end %>
      <p class="text-base-300/75 text-center">Welcome! Enter your email and password to view your gallery</p>
    """
  end

  def maybe_show_logo?(assigns) do
    ~H"""
    <h1 class="pt-3 text-2xl font-light font-client text-base-300 text-center mb-2">Welcome!</h1>
    <p class="text-base-300/75 text-center">Enter your email and password to view your gallery</p>
    """
  end

  defp assign_password_change(socket, params \\ %{}) do
    params
    |> Galleries.gallery_password_change()
    |> then(&assign(socket, :password_changeset, &1))
  end

  defp update_emails_map(email, gallery) do
    new_email_map = %{
      "email" => email,
      "viewed_at" => DateTime.utc_now()
    }

    email_list = gallery.gallery_analytics || []
    updated_email_list = email_list ++ [new_email_map]

    Galleries.update_gallery(gallery, %{gallery_analytics: updated_email_list})
  end
end
