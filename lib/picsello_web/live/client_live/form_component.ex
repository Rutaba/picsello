defmodule PicselloWeb.Live.ClientLive.ClientFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{
    Job,
    Clients,
    Package
  }

  alias Ecto.Changeset

  import PicselloWeb.Live.Shared

  import PicselloWeb.JobLive.Shared,
    only: [
      presign_entry: 2,
      assign_uploads: 2,
      process_cancel_upload: 2
    ]

  @upload_options [
    accept: ~w(.pdf .docx .txt),
    auto_upload: true,
    max_entries: String.to_integer(Application.compile_env(:picsello, :documents_max_entries)),
    max_file_size: String.to_integer(Application.compile_env(:picsello, :document_max_size)),
    external: &presign_entry/2,
    progress: &handle_progress/3
  ]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_job_types()
    |> assign_changeset()
    |> assign(
      step: :add_client,
      steps: [:add_client, :package_payment, :invoice, :documents]
    )
    |> assign(:pre_picsello_client, false)
    |> assign_new(:job, fn -> nil end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1} end)
    |> assign_uploads(@upload_options)
    |> assign(:ex_documents, [])
    |> assign_job_changeset(%{})
    |> assign_package_changeset(%{})
    |> assign_payments_changeset(%{"payment_schedules" => [%{}, %{}]})
    |> ok()
  end

  @impl true
  def render(%{changeset: changeset} = assigns) do
    ~H"""
      <div class="flex flex-col modal">

        <%= if @pre_picsello_client do %>
          <div class="flex mb-2">
            <a {if step_number(@step, @steps) > 1, do: %{href: "#", phx_click: "back", phx_target: @myself, title: "back"}, else: %{}} class="flex">
              <span {testid("step-number")} class="px-2 py-0.5 mr-2 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300">
                Step <%= step_number(@step, @steps) %>
              </span>

              <ul class="flex items-center inline-block">
                <%= for step <- @steps do %>
                  <li class={classes(
                    "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
                    %{ "bg-blue-planning-300" => step == @step, "bg-gray-200" => step != @step }
                    )}>
                  </li>
                <% end %>
              </ul>
            </a>

            <%= if step_number(@step, @steps) > 1 do%>
              <.client_name_box changeset={changeset} assigns={assigns} />
            <% end %>
          </div>
        <% end %>

        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mt-2 mb-4 text-3xl"><strong class="font-bold"><%= if @client, do: "Edit Client: ", else: "Add Client: "%></strong> <%= heading_subtitle(@step) %></h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.step {assigns} />
      </div>
    """
  end

  def step(%{step: :add_client} = assigns) do
    ~H"""
      <.form for={@changeset} let={f} phx_submit={:submit} phx-change="validate" phx-target={@myself}>
        <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
          <%= labeled_input f, :name, placeholder: "First and last name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500" %>
          <%= labeled_input f, :email, type: :email_input, placeholder: "email@example.com", phx_debounce: "500" %>
          <%= labeled_input f, :phone, type: :telephone_input, placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500" %>
          <%= labeled_input f, :address, placeholder: "Street Address", phx_debounce: "500", optional: true %>
        </div>
        <%= if !@client do %>
          <div class="mt-2">
            <div class="flex items-center justify-between mb-2">
              <%= label_for f, :notes, label: "Notes", optional: true %>

              <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(f,:notes)}>
                Clear
              </.icon_button>
            </div>

            <fieldset>
              <%= input f, :notes, type: :textarea, placeholder: "Optional notes", class: "w-full max-h-60", phx_hook: "AutoHeight", phx_update: "ignore" %>
            </fieldset>
          </div>

          <h1 class="mt-5 text-xl font-bold">Pre-Picsello Client</h1>
          <label class="flex items-center mt-4">
            <input type="checkbox" class="w-6 h-6 mt-1 checkbox" phx-click="toggle-pre-picsello" checked={@pre_picsello_client} phx-target={@myself} />
            <p class="ml-3"> This is an old client and I want to add some historic information</p>
          </label>
          <p class="ml-8"><i>(Adds a few more steps - if you don't know what this is, leave unchecked)</i></p>
          <%= if @pre_picsello_client do %>
            <div id="show-div" class="sm:col-span-3 mt-3">
              <p class="ml-8 mt-4 font-bold">In order for this client import to sync with your Picsello account, select the type of job to start import.</p>
              <div class="ml-8 grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
                <%= for job_type <- @job_types do %>
                  <.job_type_option type="radio" class={"checkbox-#{job_type}"} name={input_name(f, :type)} job_type={job_type} checked={input_value(f, :type) == job_type} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
        <div class="pt-40"></div>
        <div {testid("modal-buttons")} class="sticky px-4 -m-4 bg-white -bottom-6 sm:px-8 sm:-m-8 sm:-bottom-8">
          <div class="flex flex-col py-6 bg-white gap-2 sm:flex-row-reverse">
            <%= if @pre_picsello_client do %>
              <button class="btn-primary" title="next" disabled={!(@changeset.valid? and input_value(f, :type))} type="submit">
                Next
              </button>
            <% else %>
              <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
                Save
              </button>
            <% end %>

            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          </div>
        </div>
      </.form>
    """
  end

  def step(%{step: :package_payment} = assigns), do: package_payment_step(assigns)

  def step(%{step: :invoice} = assigns), do: invoice_step(assigns)

  def step(%{step: :documents, changeset: changeset} = assigns) do
    assigns =
      Enum.into(assigns, %{
        searched_client: nil,
        selected_client: nil,
        client_name: Changeset.get_field(changeset, :name)
      })

    documents_step(assigns)
  end

  @impl true
  def handle_event("back", %{}, socket), do: go_back_event("back", %{}, socket) |> noreply()

  @impl true
  def handle_event("remove-payment", %{}, socket),
    do: remove_payment_event("remove-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event("add-payment", %{}, socket),
    do: add_payment_event("add-payment", %{}, socket) |> noreply()

  @impl true
  def handle_event("submit", params, %{assigns: %{step: :package_payment}} = socket),
    do: payment_package_submit_event("submit", params, socket) |> noreply()

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :invoice}} = socket),
    do: invoice_submit_event("submit", %{}, socket) |> noreply()

  @impl true
  def handle_event("validate", %{"package" => _} = params, socket),
    do: validate_package_event("validate", params, socket) |> noreply()

  @impl true
  def handle_event("validate", %{"custom_payments" => params}, socket),
    do: validate_payments_event("validate", %{"custom_payments" => params}, socket) |> noreply()

  @impl true
  def handle_event(
        "submit",
        %{"client" => %{"type" => type} = params},
        %{assigns: %{step: :add_client, changeset: changeset}} = socket
      ) do
    case changeset do
      %{valid?: true} ->
        socket
        |> assign(
          step: :package_payment,
          job_type: type
        )
        |> assign_job_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        %{"client" => params},
        %{assigns: %{step: :add_client}} = socket
      ) do
    case save_client(params, socket) do
      {:ok, client} ->
        send(socket.parent_pid, {:update, %{client: client}})
        socket |> close_modal() |> redirect(to: "/clients/#{client.id}") |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event(
        "toggle-pre-picsello",
        %{},
        %{assigns: %{pre_picsello_client: pre_picsello_client}} = socket
      ) do
    socket
    |> assign(:pre_picsello_client, !pre_picsello_client)
    |> noreply()
  end

  @impl true
  def handle_event("start_another_job", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, true)
      |> import_job_for_form_component()
      |> noreply()

  @impl true
  def handle_event("submit", %{}, %{assigns: %{step: :documents}} = socket),
    do:
      socket
      |> assign(:another_import, false)
      |> import_job_for_form_component()
      |> noreply()

  @impl true
  def handle_event("validate", %{"client" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"client" => params},
        socket
      ) do
    case save_client(params, socket) do
      {:ok, client} ->
        send(socket.parent_pid, {:update, %{client: client}})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event(
        "cancel-upload",
        %{"ref" => ref},
        %{assigns: %{ex_documents: ex_documents}} = socket
      ) do
    socket
    |> assign(:ex_documents, Enum.reject(ex_documents, &(&1.ref == ref)))
    |> process_cancel_upload(ref)
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  defp save_client(params, %{assigns: %{current_user: current_user, client: nil}}) do
    Clients.save_new_client(params, current_user.organization_id)
  end

  defp save_client(params, %{assigns: %{client: client}}) do
    Clients.update_client(client, params)
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user, client: nil}},
         params
       ) do
    Clients.new_client_changeset(params, current_user.organization_id)
  end

  defp build_changeset(%{assigns: %{client: client}}, params) do
    Clients.edit_client_changeset(client, params)
  end

  defp assign_changeset(socket, action \\ nil, params \\ %{})

  defp assign_changeset(socket, :validate, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_changeset(socket, action, params) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def open(%{assigns: %{current_user: current_user}} = socket, client \\ nil) do
    socket |> open_modal(__MODULE__, %{current_user: current_user, client: client})
  end

  defp assign_job_types(%{assigns: %{current_user: %{organization: organization}}} = socket) do
    socket
    |> assign_new(:job_types, fn ->
      (organization.profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq()
    end)
  end

  defp assign_job_changeset(
         socket,
         params,
         action \\ nil
       ) do
    changeset =
      params
      |> Job.create_changeset()
      |> Map.put(:action, action)

    assign(socket, job_changeset: changeset)
  end
end
