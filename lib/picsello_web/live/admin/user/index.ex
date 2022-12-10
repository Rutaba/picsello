defmodule PicselloWeb.Live.Admin.User.Index do
  @moduledoc "Find and select user"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, Accounts.User}

  import Ecto.Query

  import PicselloWeb.LayoutView,
    only: [
      flash: 1
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
    <div class="p-8">
      <%= form_tag("#", [phx_change: :search, phx_submit: :search]) do %>
        <div class="flex flex-col px-1.5 mb-10">
          <label for="search_phrase_input" class="text-lg font-bold block mb-2">Enter user email</label>
          <input type="text" class="form-control w-full text-input" id="search_phrase_input" name="search_phrase" value={"#{@search_phrase}"} phx-debounce="500" spellcheck="false" placeholder="heyyou@picsello.com…" />
        </div>
      <% end %>
      <div class="grid grid-cols-4 gap-8">
        <%= for(%{id: id, name: name, email: email, organization_id: organization_id} <- @users) do %>
          <div class="p-4 border rounded-lg">
            <h3 class="text-2xl font-bold"><%= name %></h3>
            <h4><%= email %></h4>
            <h4>Organization id: <%= organization_id %></h4>
            <h5 class="mt-4 upppercase font-bold">Actions</h5>
            <%= live_redirect "Upload contacts", to: Routes.admin_user_contact_upload_path(@socket, :show, id), class: "underline text-blue-planning-300" %>
          </div>
        <% end %>
      </div>
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
    |> then(fn socket ->
      socket
      |> find_users()
    end)
    |> noreply()
  end

  defp find_users(%{assigns: %{search_phrase: search_phrase}} = socket) do
    users =
      Repo.all(
        from u in User,
          where: ilike(u.email, ^"%#{search_phrase}%"),
          order_by: [asc: u.email]
      )

    socket |> assign(:users, users)
  end
end
