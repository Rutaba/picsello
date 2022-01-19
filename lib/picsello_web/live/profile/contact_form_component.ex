defmodule PicselloWeb.Live.Profile.ContactFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Profiles}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = assigns |> Enum.into(%{header_suffix: ""})

    ~H"""
    <div class="border rounded-lg p-9 border-base-200">
      <h2 class="text-3xl font-bold max-w-md">Get in touch<%= @header_suffix %></h2>

      <div class="w-1/3 h-2 mt-4 lg:w-1/4" style={"background-color: #{@color}"}></div>

      <%= if @changeset do %>
        <.form for={@changeset} let={f} phx-change="validate-contact" phx-submit="save-contact" id="contact-form" phx_target={@myself}>
          <div class="flex flex-col mt-3">
            <%= label_for f, :name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", label: "Your name", class: "py-2 font-bold" %>

            <%= input f, :name, placeholder: "Type your first and last name...", class: "p-5", phx_debounce: 300 %>
          </div>

          <div class="flex flex-col lg:flex-row">
            <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
              <%= label_for f, :email, label: "Your email", class: "py-2 font-bold" %>

              <%= input f, :email, type: :email_input, placeholder: "Type email...", class: "p-5", phx_debounce: 300 %>
            </div>

            <div class="flex flex-col flex-1 mt-3">
              <%= label_for f, :phone, label: "Your phone number", class: "py-2 font-bold" %>

              <%= input f, :phone, type: :telephone_input, placeholder: "Type phone number...", class: "p-5", phx_debounce: 300, phx_hook: "Phone" %>
            </div>
          </div>

          <div class="mt-7 grid grid-cols-1 lg:grid-cols-2 gap-4">
            <%= label_for f, :job_type, label: "What photography type are you interested in?", class: "py-2 font-bold col-span-1 lg:col-span-2" %>

            <%= for job_type <- @job_types do %>
              <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={input_value(f, :job_type) == job_type} />
            <% end %>
          </div>

          <div class="flex flex-col mt-7">
            <%= label_for f, :message, label: "Your message", class: "py-2 font-bold" %>

            <%= input f, :message, type: :textarea, placeholder: "Type your message...", class: "p-5", rows: 5, phx_debounce: 300 %>
          </div>

          <div class="mt-8 text-right"><button type="submit" disabled={!@changeset.valid?} class="w-full lg:w-auto btn-primary">Submit</button></div>
        </.form>
      <% else %>
        <div class="flex items-center mt-14 min-w-max">
          <.icon name="confetti" class="w-20 h-20 stroke-current mr-9" style={"color: #{@color}"} />
          <div>
            <h2 class="text-2xl font-bold">Message sent</h2>
            We'll contact you soon!
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp assign_changeset(%{assigns: %{job_types: types}} = socket) do
    params =
      case types do
        [job_type] -> %{job_type: job_type}
        _ -> %{}
      end

    assign(socket, :changeset, Profiles.contact_changeset(params))
  end

  @impl true
  def handle_event("validate-contact", %{"contact" => params}, socket) do
    socket
    |> assign(changeset: params |> Profiles.contact_changeset() |> Map.put(:action, :validate))
    |> noreply()
  end

  @impl true
  def handle_event(
        "save-contact",
        %{"contact" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.handle_contact(organization, params) do
      {:ok, _contact} ->
        socket
        |> assign(changeset: nil)
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end
end
