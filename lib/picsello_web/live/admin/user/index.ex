defmodule PicselloWeb.Live.Admin.User.Index do
  @moduledoc "Find and select user"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, Accounts.User}

  import Ecto.Query

  import PicselloWeb.LayoutView,
    only: [
      flash: 1,
      admin_banner: 1
    ]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:search_phrase, nil)
    |> assign(:users, [])
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= flash(@flash) %>
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Find user to edit</h1>
      <p class="text-md">Search your user and pick the action you'd like to do</p>
    </header>
    <div class="p-8" phx-hook="showAdminBanner" id="show-admin-banner">
      <%= form_tag("#", [phx_change: :search, phx_submit: :search]) do %>
        <div class="flex flex-col px-1.5 mb-10">
          <label for="search_phrase_input" class="text-lg font-bold block mb-2">Enter user email</label>
          <input type="text" class="form-control w-full text-input" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" spellcheck="false" placeholder="heyyou@picsello.com…" />
        </div>
      <% end %>
      <div class="grid grid-cols-4 gap-8">
        <%= for({%{user: %{id: id, name: name, email: email, organization_id: organization_id}, changeset: changeset}, index} <- Enum.with_index(@users)) do %>
          <div class="p-4 border rounded-lg">
            <h3 class="text-2xl font-bold"><%= name %></h3>
            <h4><%= email %></h4>
            <h4>Organization id: <%= organization_id %></h4>
            <h5 class="mt-4 upppercase font-bold">Actions</h5>
            <.form let={f} for={changeset} phx-change="save" id={"form-user-#{id}"} class="mb-4" phx-value-index={index}>
              <label class="flex items-center mt-3">
                <input type="hidden" name="index" value={index} />
                <%= checkbox(f, :is_test_account, class: "w-5 h-5 mr-2.5 checkbox") %>
                <span>Is user a test account? (exclude from analytics)</span>
              </label>
            </.form>
            <hr class="mb-4" />
            <%= live_redirect "Upload contacts", to: Routes.admin_user_contact_upload_path(@socket, :show, id), class: "underline text-blue-planning-300" %>
            <form action={Routes.user_admin_session_path(@socket, :create)} method="POST" class="mt-4">
              <%= csrf_input_tag("/admin/users/log_in") %>
              <input type="hidden" value={id} name="user_id" />
              <button type="submit" class="block btn-tertiary">Log in as user (danger)</button>
            </form>
          </div>
        <% end %>
      </div>
      <.admin_banner socket={@socket} />
    </div>
    """
  end

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        socket
      ) do
    search_phrase = String.trim(search_phrase)

    search_phrase =
      if String.length(search_phrase) > 0, do: String.downcase(search_phrase), else: nil

    socket
    |> assign(search_phrase: search_phrase)
    |> find_users()
    |> noreply()
  end

  def handle_event(
        "save",
        %{"user" => user, "index" => index},
        %{assigns: %{users: users}} = socket
      ) do
    index = String.to_integer(index)
    %{user: selected_user} = Enum.at(users, index)

    case User.is_test_account_changeset(selected_user, user) |> Repo.update() do
      {:ok, _} ->
        socket |> put_flash(:success, "User updated")

      {:error, _} ->
        socket |> put_flash(:error, "Something went wrong")
    end
    |> find_users()
    |> noreply()
  end

  defp find_users(%{assigns: %{search_phrase: search_phrase}} = socket) do
    users =
      Repo.all(
        from u in User,
          where: ilike(u.email, ^"%#{search_phrase}%"),
          order_by: [asc: u.email]
      )
      |> Enum.map(&%{user: &1, changeset: User.is_test_account_changeset(&1)})

    socket |> assign(:users, users)
  end
end
