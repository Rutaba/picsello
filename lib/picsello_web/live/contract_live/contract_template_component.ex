defmodule PicselloWeb.ContractTemplateComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Contract, Contracts}
  alias Picsello.{Contract, Profiles, Repo}
  import PicselloWeb.Live.Contracts.Index, only: [get_contract: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:content_edited, false)
    |> assign(:edit_contract?, true)
    |> assign(:client_preview?, false)
    |> assign_job_types()
    |> assign_changeset(%{}, %{})
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <div class="sm:flex items-center gap-4">
      <.step_heading state={@state} />
        <%= if is_nil(@state) do %>
          <div {testid("view-only")}><.badge color={:gray}>View Only</.badge></div>
        <% end %>
      </div>

      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="flex bg-base-200 items-center rounded-lg">
          <div class="flex gap-4 items-center">
            <div class={classes("cursor-pointer text-blue-planning-300 font-bold text-lg border-b-4 transition-all shrink-0", %{"opacity-100 border-b-blue-planning-300" => @edit_contract?, "border-b-transparent hover:opacity-100" => !@edit_contract?})}>
              <div phx-click="show_edit_contract" phx-target={@myself} class={classes("p-2 flex items-center text-sm font-semibold", %{"text-blue-planning-300" => @edit_contract?, "text-base-250" => !@edit_contract?})}>
                <.icon name="pencil" class="inline-block w-3.5 h-3.5 mx-2 fill-current" />
                <span>Edit</span>
              </div>
            </div>
            <div class={classes("cursor-pointer text-blue-planning-300 font-bold text-lg border-b-4 transition-all shrink-0", %{"opacity-100 border-b-blue-planning-300" => @client_preview?, "border-b-transparent hover:opacity-100" => !@client_preview?})}>
              <div phx-click="show_client_preview" phx-target={@myself} class={classes("p-2 flex items-center text-sm font-semibold", %{"text-blue-planning-300" => @client_preview?, "text-base-250" => !@client_preview?})}>
                <.icon name="eye" class="inline-block w-3.5 h-3.5 mx-2 fill-current" />
                <span>Client Preview</span>
              </div>
            </div>
          </div>
          <%= if input_value(f, :job_type) do %>
            <div class="ml-auto flex px-3">
              <div class="flex items-center justify-center w-7 h-7 ml-1 mr-3 rounded-full flex-shrink-0 text-white bg-blue-planning-300">
                <.icon name={input_value(f, :job_type)} class="fill-current" width="14" height="14" />
              </div>
              <span><%= String.capitalize(input_value(f, :job_type)) %></span>
            </div>
          <% end %>
        </div>

        <%= if @edit_contract? do %>
          <div class="flex flex-col text-sm my-4">
            <span class="font-semibold">TIP: Dynamic Contracts</span>
            <p class="text-base-250">Client name, package pricing, and shoot information are generated once a package is selected in a lead to pair with your Terms & Conditions. Check out the “Client Preview” tab to see what we mean!</p>
          </div>

          <%= hidden_input f, :package_id %>

          <div class={classes(%{"grid gap-3" => @state == :edit_lead})}>
            <%= if @state == :edit_lead do %>
              <%= labeled_input f, :name, label: "Contract Internal Name", disabled: is_nil(@state) %>
            <% else %>
              <%= labeled_input f, :name, label: "Contract Internal Name", disabled: is_nil(@state) %>
            <% end %>
          </div>

          <div class={classes("mt-8", %{"hidden" => @state == :edit_lead})}>
            <div class="flex items-center">
              <%= label_for f, :type, label: "Contract Photography Type" %>
              <.icon name="tooltip" class="inline-block w-3.5 h-3.5 mx-1 fill-current text-blue-planning-300" />
              <span class="ml-auto text-sm underline text-blue-planning-300">I need more help</span>
            </div>
            <p class="text-base-250">Select “Global” so your contract will show up for all photography types or select only the one you want to use that contract for. </p>
            <div class="grid grid-cols-2 gap-3 mt-2 sm:grid-cols-4 sm:gap-5">
              <%= for job_type <- @job_types do %>
                <.job_type_option type="radio" name={input_name(f, :job_type)} job_type={job_type} checked={input_value(f, :job_type) == job_type} disabled={is_nil(@state)} />
              <% end %>
            </div>
          </div>
          <hr class="my-8" />
          <div class="flex justify-between items-end pb-2">
            <label class="block mt-4 input-label" for={input_id(f, :content)}>Terms & Conditions Language</label>
            <%= cond do %>
              <% @content_edited -> %>
                <.badge color={:blue}>Edited—new template will be saved</.badge>
              <% !@content_edited -> %>
                <.badge color={:gray}>No edits made</.badge>
            <% end %>
          </div>
          <.quill_input f={f} id="quill_contract_input" html_field={:content} enable_size={true} track_quill_source={true} editable={editable(is_nil(@state))} placeholder="Paste contract text here" />
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 items-center gap-4 md:gap-10 mt-6">
              <div class="font-light">
                <h1 class="text-3xl font-medium">
                  Contract for {{client_name}}
                </h1>

                <p class="text-base-250 mt-2">Accepted on {{date}}</p>

                <p class="mt-2 text-base-250">{{package price}} USD</p>
                <p class="text-base-250 mt-2">{{photo_information}}</p>

                <hr class="my-4" />
                <div class="mt-2 mb-4">
                  <div class="line-clamp-2 raw_html raw_html_inline mb-4 text-base-250">
                    {{package_description}}
                  </div>
                  <button class="flex items-center font-light text-base-250 view_more_click" type="button">
                    <span>See more</span> <.icon name="down" class="text-base-250 h-4 w-4 stroke-current stroke-2 ml-1 transition-transform" />
                  </button>
                </div>
              </div>
              <div>
                <div class="rounded-lg p-4 items-center flex flex-col w-full h-[300px] mr-4 md:mr-7 bg-base-200">
                  <div class="flex flex-col justify-center h-full items-center">
                    <.icon name="photos-2" class="inline-block w-9 h-9 text-base-250"/>
                    <span class="mt-1 text-base-250 text-center">Optional package thumbnail</span>
                  </div>
                </div>
              </div>
            </div>

            <hr class="mt-8 mb-8" />

            <div class="mt-4 grid grid-cols-2 sm:grid-cols-[2fr,2fr] gap-4 sm:gap-6">
              <div class="modal-banner uppercase font-light py-2 bg-base-200 grid grid-cols-[2fr,2fr] gap-4 col-span-2">
                <h2>Item</h2>
                <h2>Details</h2>
              </div>

              <div {testid("shoot-title")} class="flex flex-col col-span-1 sm:col-span-1 pl-4 md:pl-8 font-light">
                <h3 class="font-light">{{shoot_name}}</h3>
                {{shoot_date}}
              </div>

              <div {testid("shoot-description")} class="flex flex-col col-span-1 sm:col-span-1 font-light">
                <p>
                  {{shoot_time}}
                </p>
                <p>{{shoot_address}}</p>
              </div>

              <hr class="col-span-2">

              <div class="flex flex-col col-span-1 sm:col-span-1 pl-4 md:pl-8 font-light">
                <h3 class="font-light">Photo Downloads</h3>
              </div>

              <div class="flex flex-col col-span-1 sm:col-span-1 font-light">
                {{digital_image_pricing}}
              </div>

              <hr class="hidden col-span-2 sm:block">

              <div class="hidden col-start-2 col-span-1 sm:block pr-4 md:pr-8">
                <div class="contents">
                  <dl class="flex justify-between text-xl font-light">
                    <dt>Total</dt>
                    <dd class="bold">{{invoice_total}} USD</dd>
                  </dl>
                </div>
              </div>
            </div>

            <hr class="mt-8 mb-8" />

            <div class="mt-4 raw_html min-h-[8rem] font-light">
              <%= raw (input_value(f, :content)) %>
            </div>

            <fieldset disabled="true">
              <%= labeled_input f, :signed_legal_name, placeholder: "type your name...", label: "Type your full legal name", phx_debounce: "500", wrapper_class: "mt-4" %>
            </fieldset>

            <p class="mt-4 text-xs text-base-250 max-w-xs">
              By typing your full legal name and clicking the submit button, you agree to sign this legally binding contract.
            </p>
        <% end %>

        <.footer>
          <%= if !is_nil(@state)do %>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
            Save
          </button>
          <% else %>
          <button title="Duplicate Table" type="button" phx-click="duplicate-contract" phx-value-contract-id={@contract.id} phx-target={@myself} class="btn-primary">
            Duplicate
          </button>
          <% end %>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            <%= if is_nil(@state) do %>Close<% else %>Cancel<% end %>
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  def step_heading(assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl font-bold"><%= heading_title(@state) %></h1>
    """
  end

  def heading_title(state) do
    case state do
      :edit -> "Edit dynamic contract"
      :edit_lead -> "Edit dynamic contract"
      :create -> "Add Contract"
      _ -> "View Contract template"
    end
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:contract]))
        }
      )

  defp assign_job_types(
         %{
           assigns: %{
             current_user: %{organization: %{organization_job_types: job_types}}
           }
         } = socket
       ) do
    socket
    |> assign_new(:job_types, fn ->
      (Profiles.enabled_job_types(job_types) ++
         [Picsello.JobType.other_type()])
      |> Enum.uniq()
    end)
  end

  defp assign_changeset(
         %{assigns: %{contract: contract}} = socket,
         action,
         params
       ) do
    attrs = Map.get(params, "contract", %{})

    changeset =
      contract
      |> Contract.template_changeset(attrs)
      |> Map.put(:action, action)

    socket
    |> assign(changeset: changeset)
  end

  @impl true
  def handle_event(
        "duplicate-contract",
        %{"contract-id" => contract_id},
        %{assigns: %{current_user: %{organization: %{id: organization_id}}} = assigns} = socket
      ) do
    id = String.to_integer(contract_id)

    contract =
      Contracts.clean_contract_for_changeset(
        get_contract(id),
        organization_id
      )
      |> Map.put(:name, nil)

    assigns = Map.merge(assigns, %{contract: contract, state: :edit})
    assigns = Map.take(assigns, [:contract, :current_user, :state])

    socket
    |> assign(assigns)
    |> noreply()
  end

  def handle_event("show_edit_contract", _params, socket) do
    socket
    |> assign(:edit_contract?, true)
    |> assign(:client_preview?, false)
    |> noreply()
  end

  def handle_event("show_client_preview", _params, socket) do
    socket
    |> assign(:edit_contract?, false)
    |> assign(:client_preview?, true)
    |> noreply()
  end

  @impl true
  def handle_event("validate", params, socket) do
    contract = Map.get(params, "contract", %{"quill_source" => ""})

    socket
    |> assign(:content_edited, Map.get(contract, "quill_source") == "user")
    |> assign_changeset(:validate, params)
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"contract" => params},
        socket
      ) do
    case save_contract(params, socket) do
      {:ok, contract} ->
        send(socket.parent_pid, {:update, %{contract: contract}})

        socket |> close_modal()

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  defp save_contract(params, %{assigns: %{contract: contract}}) do
    params =
      params
      |> Map.put("organization_id", contract.organization_id)
      |> Map.put("package_id", nil)
      |> Map.put("contract_template_id", nil)

    contract =
      contract |> Map.drop([:contract_template_id, :organization, :package, :contract_template])

    contract
    |> Contract.template_changeset(params)
    |> Repo.insert_or_update()
  end

  defp editable(false), do: "true"
  defp editable(true), do: "false"
end
