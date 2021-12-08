defmodule PicselloWeb.Live.Profile do
  @moduledoc "photographers public profile"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.Profiles

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket |> assign_defaults(session) |> assign_organization(slug) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-grow border-b-8" style={"border-color: #{@color}"}>
      <div class="px-6 py-4 md:py-8 md:px-16 center-container">
        <.default_logo color={@color} photographer={@photographer} />
      </div>

      <hr class="border-base-200">

      <div class="flex flex-col px-6 mt-10 mb-16 md:mb-32 md:mt-20 md:px-16 md:flex-row center-container">
        <div class="mb-10 mr-0 md:mr-10 center-container">
          <h1 class="text-5xl font-bold text-center md:text-6xl md:text-left"><%= @organization.name %></h1>

          <h2 class="mt-12 text-lg font-bold">What we offer:</h2>

          <div class="w-1/4 h-2" style={"background-color: #{@color}"}></div>

          <div class="w-auto md:w-min">
            <%= for job_type <- @organization.user.onboarding.job_types do %>
              <div class="flex my-4 p-4 items-center font-semibold rounded-lg bg-[#fafafa]">
                <span style={"color: #{@color};"}>
                  <.icon name={job_type} class="mr-6 fill-current w-9 h-9" />
                </span>

                <span class="whitespace-nowrap"><%= dyn_gettext job_type %></span>
              </div>
            <% end %>
          </div>

          <%= if @website do %>
            <a href={@website} style="text-decoration-thickness: 2px" class="block pt-2 underline underline-offset-1" href="#">See our full portfolio</a>
          <% end %>
        </div>

        <div class="flex flex-col">
          <div class="border rounded-lg p-9 border-base-200">
            <h2 class="text-3xl font-bold">Get in touch</h2>

            <div class="w-1/3 h-2 mt-4 lg:w-1/4" style={"background-color: #{@color}"}></div>

            <.form for={:contact} let={f} >
              <div class="flex flex-col mt-3">
                <%= label_for f, :name, label: "Your name", class: "py-2 font-bold" %>

                <%= input f, :name, placeholder: "Type your first and last name...", class: "p-5" %>
              </div>

              <div class="flex flex-col lg:flex-row">
                <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
                  <%= label_for f, :email, label: "Your email", class: "py-2 font-bold" %>

                  <%= input f, :email, placeholder: "Type email...", class: "p-5" %>
                </div>

                <div class="flex flex-col flex-1 mt-3">
                  <%= label_for f, :phone, label: "Your phone nuber", class: "py-2 font-bold" %>

                  <%= input f, :phone, placeholder: "Type phone number...", class: "p-5" %>
                </div>
              </div>

              <div class="mt-7 grid grid-cols-1 lg:grid-cols-2 gap-4">
                <%= label_for f, :job_type, label: "What photography type are you interested in?", class: "py-2 font-bold col-span-1 lg:col-span-2" %>

                <%= for job_type <- @organization.user.onboarding.job_types do %>
                  <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={false} />
                <% end %>
              </div>

              <div class="flex flex-col mt-7">
                <%= label_for f, :message, label: "Your message", class: "py-2 font-bold" %>

                <%= input f, :message, type: :textarea, placeholder: "Type your message...", class: "p-5", rows: 5 %>
              </div>

              <div class="mt-8 text-right"><button class="w-full lg:w-auto btn-primary">Submit</button></div>
            </.form>
          </div>
        </div>
      </div>
    </div>

    <footer class="px-6 md:px-16 center-container">
      <div class="flex justify-center py-8 md:justify-start md:py-14"><.default_logo color={@color} photographer={@photographer} /></div>

      <div class="flex flex-col items-center justify-start pt-6 mb-8 border-t md:flex-row md:justify-between border-base-250 text-base-300 opacity-30">
        <span>© <%= Date.utc_today().year %> <%= @organization.name %></span>

        <span class="mt-2 md:mt-0">Powered By Picsello</span>
      </div>
    </footer>
    """
  end

  defp default_logo(assigns) do
    ~H"""
      <.initials_circle style={"background-color: #{@color}"} class="pb-1 text-2xl font-bold w-14 h-14 text-base-100" user={@photographer} />

    """
  end

  defp assign_organization(socket, slug) do
    %{user: %{onboarding: onboarding} = user} =
      organization = Profiles.find_organization_by(slug: slug)

    assign(socket,
      organization: organization,
      color: onboarding.color,
      website: onboarding.website,
      photographer: user
    )
  end
end
