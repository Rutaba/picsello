defmodule PicselloWeb.EmailAutomationLive.EditTimeComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Ecto.Changeset
  alias Picsello.{Repo, EmailPresets.EmailPreset}
  alias PicselloWeb.EmailAutomationLive.Shared

  @impl true
  def update(
        %{
          current_user: _current_user,
          email: email
        } = assigns,
        socket
      ) do
    email_automation_setting =
      if email.total_hours == 0 do
        email |> Map.put(:immediately, true)
      else
        data = Shared.explode_hours(email.total_hours)

        Map.merge(email, data)
        |> Map.put(:immediately, false)
      end

    changeset = email_automation_setting |> EmailPreset.changeset(%{})

    socket
    |> assign(assigns)
    |> assign(email_automation_setting: email_automation_setting)
    |> assign(changeset: changeset)
    |> ok()
  end

  defp step_valid?(assigns),
    do:
      Enum.all?(
        [
          assigns.changeset
        ],
        & &1.valid?
      )

  @impl true
  def handle_event(
        "validate",
        %{"email_preset" => params},
        %{assigns: %{email_automation_setting: email_automation_setting}} = socket
      ) do
    changeset = EmailPreset.changeset(email_automation_setting, maybe_normalize_params(params))

    socket
    |> assign(changeset: changeset)
    |> noreply()
  end

  @impl true
  def handle_event("submit", _, socket) do
    socket
    |> save()
    |> close_modal()
    |> noreply()
  end

  defp save(
         %{
           assigns: %{
             changeset: email_preset_changeset,
             email: email,
             current_user: %{organization_id: organization_id}
           }
         } = socket
       ) do
    
    changeset = if is_nil(email.organization_id) do
      email_preset_changeset
      |> current()
      |> Map.merge(%{
        id: nil,
        organization_id: organization_id,
        inserted_at: email.inserted_at,
        updated_at: email.updated_at
      })
      |> EmailPreset.changeset(%{})
    else
      Ecto.Changeset.put_change(email_preset_changeset, :id, email.id)
    end

    case Repo.insert(changeset,
    on_conflict: {:replace, [:total_hours, :condition, :status]},
    conflict_target: :id
  ) do
    {:ok, email_automation_setting} ->
    send(
      self(),
      {:update_automation,
        %{email_automation_setting: email_automation_setting, message: "successfully updated"}}
    )

    socket

    {:error, changeset} ->
    socket
    |> assign(changeset: changeset)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.close_x />
        <h1 class="mt-2 mb-4 text-3xl">
          <span class="font-bold">Edit Email Automation Settings</span>
        </h1>

        <.form for={@changeset} phx-change="validate" phx-submit="submit" phx-target={@myself} id={"form-timing"}>
          <input type="hidden" />

          <div class="rounded-lg border-base-200 border">
            <div class="bg-base-200 p-4 flex rounded-t-lg">
              <div class="flex flex-row items-center">
                <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
                  <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
                </div>
                <span class="text-blue-planning-300 text-lg"><b>Send email:</b> <%= @pipeline.name %></span>
              </div>
              <div class="flex ml-auto items-center">
                <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
                  <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
                </div>
                <span>Job Automation</span>
              </div>
            </div>

            <% f = to_form(@changeset) %>
            <%= hidden_input f, :email_automation_pipeline_id %>
            <%= hidden_input f, :type %>
            <%= hidden_input f, :job_type %>
            <%= hidden_input f, :name %>
            <%= hidden_input f, :state %>
            <%= hidden_input f, :body_template %>
            <%= hidden_input f, :subject_template %>
            <%= hidden_input f, :position %>
            <%= hidden_input f, :private_name %>
            <%= hidden_input f, :organization_id %>

            <div class="flex md:flex-row flex-col w-full md:px-14 px-6 py-6">

              <div class="flex flex-col w-full md:pr-6">
                <b>Email timing</b>
                <span class="text-base-250">Choose when you’d like your email to send</span>
                <div class="flex gap-4 flex-col my-4">
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :immediately, true, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Send immediately when event happens</p>
                  </label>
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :immediately, false, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Send at a certain time</p>
                  </label>
                  <%= unless current(@changeset) |> Map.get(:immediately) do %>
                    <div class="flex flex-col ml-8">
                      <div class="flex w-full my-2">
                        <div class="w-1/5">
                          <%= input f, :count, class: "border-base-200 hover:border-blue-planning-300 cursor-pointer w-full" %>
                        </div>
                          <div class="ml-2 w-3/5">
                          <%= select f, :calendar, ["Day", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                        </div>
                        <div class="ml-2 w-3/5">
                          <%= select f, :sign, [Before: "-", After: "+"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                        </div>
                      </div>
                      <%= if message = @changeset.errors[:count] do %>
                        <div class="flex py-1 w-full text-red-sales-300 text-sm"><%= translate_error(message) %></div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <b>Email Status</b>
                <span class="text-base-250">Choose whether or not this email should send</span>

                <div>
                  <label class="flex pt-4">
                    <%= checkbox f, :status, class: "peer hidden", checked: Changeset.get_field(@changeset, :status) == :active %>
                    <div class="hidden peer-checked:flex cursor-pointer">
                      <div class="rounded-full bg-blue-planning-300 border border-base-100 w-14 p-1 flex justify-end mr-4">
                        <div class="rounded-full h-5 w-5 bg-base-100"></div>
                      </div>
                      Email enabled
                    </div>
                    <div class="flex peer-checked:hidden cursor-pointer">
                      <div class="rounded-full w-14 p-1 flex mr-4 border border-blue-planning-300">
                        <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                      </div>
                      Email disabled
                    </div>
                  </label>
                </div>
              </div>

              <hr class="my-4 md:hidden flex" />

              <div class="flex flex-col w-full md:pl-6 md:border-l md:border-base-200 hidden">
                <b>Email Automation sequence conditions</b>
                <span class="text-base-250">Choose to run automatically or when conditions are met</span>
                <div class="flex gap-4 flex-col my-4">
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :normally, true, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Run automation normally</p>
                  </label>
                  <label class="flex items-center cursor-pointer">
                    <%= radio_button(f, :normally, false, class: "w-5 h-5 mr-4 radio") %>
                    <p class="font-semibold">Run automation only if:</p>
                  </label>
                  <%= unless input_value(f, :normally) do %>
                    <div class="flex my-2 ml-8">
                      <%= select f, :condition, ["Client doesn’t respond by email send time", "Month", "Year"], wrapper_class: "mt-4", class: "w-full py-3 border rounded-lg border-base-200", phx_update: "update" %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <.footer class="pt-10">
            <button class="btn-primary" title="Save" disabled={!step_valid?(assigns)} type="submit" phx-disable-with="Save">
              Save
            </button>
            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Close
            </button>
          </.footer>
        </.form>
      </div>
    """
  end

  defp maybe_normalize_params(params) do
    {_, params} =
      get_and_update_in(
        params,
        ["status"],
        &{&1, if(&1 == "true", do: :active, else: :disabled)}
      )

    params
  end
end
