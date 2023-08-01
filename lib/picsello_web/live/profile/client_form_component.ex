defmodule PicselloWeb.Live.Profile.ClientFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Profiles}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> assign_changeset()
    |> assign(:additional_field, false)
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = assigns |> Enum.into(%{header_suffix: ""})

    ~H"""
    <div class="mt-20 border p-9 border-base-200">
      <h2 class="text-3xl font-light max-w-md">Get in touch<%= @header_suffix %></h2>

      <%= if @changeset do %>
        <.form for={@changeset} :let={f} phx-change="validate-client" phx-submit="save-client" id="contact-form" phx-target={@myself}>
          <div class="flex flex-col mt-3">
            <%= label_for f, :name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", label: "Your name", class: "py-2 font-light" %>

            <%= input f, :name, placeholder: "Type your first and last name...", phx_debounce: 300 %>
          </div>

          <div class="flex flex-col lg:flex-row">
            <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
              <%= label_for f, :email, label: "Your email", class: "py-2 font-light" %>

              <%= input f, :email, type: :email_input, placeholder: "Type email...", phx_debounce: 300 %>
            </div>

            <div class="flex flex-col flex-1 mt-3">
              <%= label_for f, :phone, label: "Your phone number", class: "py-2 font-light" %>

              <%= input f, :phone, type: :telephone_input, placeholder: "Type phone number...", phx_debounce: 300 %>
            </div>
          </div>

          <div class="flex flex-col mt-3">
            <%= labeled_select f, :referred_by, referred_by_options(), label: "How did you hear about #{@organization.name}?", prompt: "select one...", phx_debounce: 300, phx_update: "ignore" %>
            <em class="text-base-250 font-normal pt-1 text-xs">optional</em>
          </div>

            <%= if @additional_field do %>
              <div class="flex flex-col mt-3">
                <% info = referral_info(f.params) %>
                <%= label_for f, :referral_name, label: info.label, class: "py-2 font-bold" %>

                <%= input f, :referral_name, placeholder: info.placeholder, phx_debounce: 300 %>
                <em class="text-base-250 font-normal pt-1 text-xs">optional</em>
              </div>
            <% end %>
          <%= if Enum.any?(@job_types) do %>
            <div class="mt-4">
              <%= label_for f, :job_type, label: "What type of session are you looking for?", class: "font-light" %>
              <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mt-1">
                <%= for job_type <- @job_types do %>
                  <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={input_value(f, :job_type) == job_type} color="black" class="rounded-none" />
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="flex flex-col mt-3">
            <%= label_for f, :message, label: "Your message", class: "py-2 font-light" %>

            <%= input f, :message, type: :textarea, placeholder: "Type your message...", rows: 5, phx_debounce: 300 %>
          </div>

          <div class="mt-8 text-right"><button type="submit" disabled={!@changeset.valid?} class="w-full lg:w-auto btn-primary">Submit</button></div>
        </.form>
      <% else %>
        <div class="flex items-center mt-14 min-w-max">
          <.icon name="confetti" class="w-20 h-20 stroke-current mr-9" style={"color: #{@color}"} />
          <div>
            <h2 class="text-2xl font-light">Message sent</h2>
            We'll contact you soon!
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp assign_changeset(%{assigns: %{job_type: job_type}} = socket) do
    assign(socket, :changeset, Profiles.contact_changeset(%{job_type: job_type}))
  end

  defp assign_changeset(%{assigns: %{job_types: types}} = socket) do
    params =
      case types do
        [job_type] -> %{job_type: job_type}
        _ -> %{}
      end

    assign(socket, :changeset, Profiles.contact_changeset(params))
  end

  defp referred_by_options() do
    [
      "Friend",
      "Google",
      "Facebook",
      "Instagram",
      "Tiktok",
      "Pinterest",
      "Event / Tradeshow",
      "Other"
    ]
  end

  defp should_show_additional_field?(referred_by) do
    referred_by in ["Friend", "Other"]
  end

  defp referral_info(params) do
    case params["referred_by"] do
      "Friend" ->
        %{
          label: "Would you mind sharing their name?",
          placeholder: "Type name..."
        }
      "Other" ->
        %{
          label: "Would you mind sharing where?",
          placeholder: "Type where..."
        }
    end
  end

  @impl true
  def handle_event(
        "validate-client",
        %{"contact" => %{"referred_by" => referred_by} = params},
        socket
      ) do
    socket
    |> assign(:additional_field, should_show_additional_field?(referred_by))
    |> assign(changeset: params |> Profiles.contact_changeset() |> Map.put(:action, :validate))
    |> noreply()
  end

  @impl true
  def handle_event(
        "save-client",
        %{"contact" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.handle_contact(organization, params, PicselloWeb.Helpers) do
      {:ok, _client} ->
        socket
        |> assign(changeset: nil)

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  defp assign_job_types(%{assigns: %{job_types: []}} = socket),
    do: assign(socket, :job_types, ["other"])

  defp assign_job_types(socket), do: socket

  defp assign_changeset(%{assigns: %{job_type: job_type}} = socket) do
    assign(socket, :changeset, Profiles.contact_changeset(%{job_type: job_type}))
  end

  defp assign_changeset(%{assigns: %{job_types: types}} = socket) do
    params =
      case types do
        [job_type] -> %{job_type: job_type}
        _ -> %{}
      end

    assign(socket, :changeset, Profiles.contact_changeset(params))
  end
end
