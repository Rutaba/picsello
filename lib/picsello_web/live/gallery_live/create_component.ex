defmodule PicselloWeb.GalleryLive.CreateComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  alias Picsello.{
    Job,
    Jobs,
    Package,
    Profiles,
    Packages,
    Packages.Download,
    Packages.PackagePricing,
    Galleries.Gallery,
    Galleries,
    Repo,
    GlobalSettings,
    Clients
  }

  alias Ecto.Multi
  alias Ecto.Changeset
  alias PicselloWeb.JobLive.GalleryTypeComponent

  import PicselloWeb.JobLive.Shared, only: [search_clients: 1, job_form_fields: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1, expired_at: 1]

  import PicselloWeb.PackageLive.Shared,
    only: [digital_download_fields: 1, print_credit_fields: 1, current: 1]

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @steps [:choose_type, :details, :pricing]

  @impl true
  def update(
        %{
          current_user:
            %{
              organization: %{id: organization_id, organization_job_types: organization_job_types}
            } = current_user
        } = assigns,
        socket
      ) do
    socket
    |> assign(assigns)
    |> assign(
      global_settings: Repo.get_by(GlobalSettings.Gallery, organization_id: organization_id)
    )
    |> assign(:new_gallery, nil)
    |> assign(:clients, Clients.find_all_by(user: current_user))
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:new_client, false)
    |> assign(current_focus: -1)
    |> assign_new(:selected_client, fn -> nil end)
    |> then(fn socket ->
      if socket.assigns[:changeset] do
        socket
      else
        assign_job_changeset(socket, %{"client" => %{}, "shoots" => [%{"starts_at" => nil}]})
      end
    end)
    |> assign_new(:package, fn -> %Package{shoot_count: 1, contract: nil} end)
    |> assign_new(:package_pricing, fn -> %PackagePricing{} end)
    |> assign(templates: [], step: :choose_type, steps: @steps)
    |> assign_package_changesets()
    |> assign(:job_types, Profiles.enabled_job_types(organization_job_types))
    |> ok()
  end

  @impl true
  def handle_event("back", %{}, %{assigns: %{step: step, steps: steps}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(:step, previous_step)
    |> noreply()
  end

  @impl true
  def handle_event("gallery_type", %{"type" => type}, socket)
      when type in ~w(proofing standard) do
    socket
    |> assign(:gallery_type, type)
    |> assign(:step, :details)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"job" => job_params}, socket) do
    socket
    |> assign_job_changeset(job_params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event("validate", params, socket) do
    socket
    |> assign_package_changesets(params, :validate)
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"job" => job_params}, socket) do
    socket
    |> assign_job_changeset(job_params)
    |> assign(:step, :pricing)
    |> noreply()
  end

  @impl true
  def handle_event(
        "submit",
        params,
        %{
          assigns: %{
            current_user: current_user,
            selected_client: selected_client,
            searched_client: searched_client,
            gallery_type: gallery_type
          }
        } = socket
      ) do
    socket
    |> assign_package_changesets(params)
    |> then(fn %{assigns: %{changeset: changeset, package_changeset: package_changeset}} ->
      job = changeset |> Changeset.apply_changes()

      client =
        cond do
          selected_client ->
            selected_client

          searched_client ->
            searched_client

          true ->
            job.client
        end

      type = changeset |> Changeset.get_field(:type)
      changeset = Changeset.delete_change(changeset, :client)

      Multi.new()
      |> Jobs.maybe_upsert_client(client, current_user)
      |> Multi.insert(:job, fn %{client: client} ->
        Changeset.put_change(changeset, :client_id, client.id)
      end)
      |> Multi.merge(fn %{job: job} ->
        Packages.insert_package_and_update_job(package_changeset, job)
      end)
      |> Multi.merge(fn %{job: %{id: job_id}} ->
        Galleries.create_gallery_multi(%{
          name: client.name <> " " <> type,
          job_id: job_id,
          status: "active",
          client_link_hash: UUID.uuid4(),
          password: Gallery.generate_password(),
          expired_at: expired_at(current_user.organization_id),
          type: gallery_type,
          albums: Galleries.album_params_for_new(gallery_type)
        })
      end)
      |> Repo.transaction()
    end)
    |> case do
      {:error, :job, changeset, _} ->
        socket |> assign(:changeset, changeset) |> assign(:step, :details)

      {:error, :package, changeset, _} ->
        assign(socket, :package_changeset, changeset)

      {:ok, %{gallery: gallery}} ->
        send(self(), {:redirect_to_gallery, gallery})
        socket |> assign(:new_gallery, gallery)
    end
    |> noreply()
  end

  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  def render(%{step: step} = assigns) do
    ~H"""
    <div class={classes("relative bg-white p-6", %{"modal" => step != :choose_type})}>
      <.close_x />

      <.steps step={step} steps={@steps} target={@myself} />

      <h1 class="mt-2 mb-4 text-3xl">
        <span class="font-bold">Create a Gallery:</span>
        <%= case step do %>
          <% :choose_type -> %> Get Started
          <% :details -> %> General Details
          <% :pricing -> %> Pricing
        <% end %>
      </h1>

      <%= if is_nil(@selected_client) && step == :details do %>
        <.search_clients new_client={@new_client} search_results={@search_results} search_phrase={@search_phrase} selected_client={@selected_client} searched_client={@searched_client} current_focus={@current_focus} clients={@clients} myself={@myself}/>
      <% end %>

      <.form
        for={@changeset}
        let={f} phx_change={:validate}
        phx_submit={:submit}
        phx_target={@myself}
        id={"form-#{step}"}
      >
        <input type="hidden" name="step" value={@step} />
        <.step name={step} f={f} {assigns} />

        <%= unless step == :choose_type do %>
          <.footer>
            <.step_button name={step} form={f} is_valid={valid?(assigns)} myself={@myself} />
            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">Cancel</button>
          </.footer>
        <% end %>

      </.form>
    </div>
    """
  end

  def step(%{name: :choose_type} = assigns) do
    ~H"""
      <%= live_component GalleryTypeComponent,
      id: "choose_gallery_type",
      target: @myself,
      main_class: "px-2",
      button_title: "Next",
      hide_close_button: true %>
    """
  end

  def step(%{name: :details} = assigns) do
    assigns = assigns |> Enum.into(%{email: nil, name: nil, phone: nil})

    ~H"""
      <.job_form_fields myself={@myself} form={@f} new_client={@new_client} job_types={@job_types} />
      <hr class="mt-10 mb-3" />
      <div class="grid md:grid-cols-2">
        <%= labeled_select form_for(@package_changeset, "#"), :shoot_count, Enum.to_list(1..10), label: "# of Shoots", phx_debounce: "500" %>
        <%= hidden_input @f, :is_gallery_only, value: true %>
      </div>
    """
  end

  def step(%{name: :pricing} = assigns) do
    ~H"""
      <div class="">
        <% package = form_for(@package_changeset, "#") %>

        <%= hidden_input package, :turnaround_weeks, value: 1 %>

        <.print_credit_fields f={package} package_pricing={@package_pricing} />

        <.digital_download_fields for={:create_gallery} package_form={package} download_changeset={@download_changeset} package_pricing={@package_pricing} />
        <%= if @new_gallery do %>
          <div id="set-gallery-cookie" data-gallery-type={@new_gallery.type} phx-hook="SetGalleryCookie">
          </div>
        <% end %>
    </div>
    """
  end

  defp valid?(%{step: :details, changeset: changeset}), do: changeset.valid?

  defp valid?(assigns) do
    Enum.all?(
      [assigns.download_changeset, assigns.package_pricing, assigns.package_changeset],
      & &1.valid?
    )
  end

  def step_button(%{name: name, is_valid: is_valid} = assigns) do
    assigns = Map.put_new(assigns, :class, "")
    title = button_title(name)

    ~H"""
    <button class="btn-primary" title={title} type="submit" disabled={!is_valid} phx-disable-with={title}>
      <%= title %>
    </button>
    """
  end

  defp button_title(:details), do: "Next"
  defp button_title(:pricing), do: "Save"

  defp assign_job_changeset(
         %{assigns: %{current_user: current_user}} = socket,
         params,
         action \\ nil
       ) do
    changeset =
      case params do
        %{"client_id" => _client_id} ->
          params
          |> Job.new_job_changeset()
          |> Map.put(:action, action)

        %{"client" => _client_params} ->
          params
          |> put_in(["client", "organization_id"], current_user.organization_id)
          |> Job.create_job_changeset()
          |> Map.put(:action, action)

        _ ->
          params
          |> Job.create_job_changeset()
          |> Map.put(:action, action)
      end

    assign(socket, :changeset, changeset)
  end

  def assign_package_changesets(
        %{
          assigns: %{
            package: package,
            package_pricing: package_pricing,
            current_user: current_user,
            step: step,
            global_settings: global_settings
          }
        } = socket,
        params \\ %{},
        action \\ nil
      ) do
    global_settings =
      if global_settings,
        do: global_settings,
        else: %{download_each_price: nil, buy_all_price: nil}

    download_params = Map.get(params, "download", %{}) |> Map.put("step", step)

    download_changeset =
      package
      |> Download.from_package(global_settings)
      |> Download.changeset(download_params)
      |> Map.put(:action, action)

    download = current(download_changeset)

    package_changeset =
      params
      |> Map.get("package", %{})
      |> PackagePricing.handle_package_params(params)
      |> Map.merge(%{
        "download_count" => Download.count(download),
        "download_each_price" => Download.each_price(download),
        "buy_all" => Download.buy_all(download),
        "name" => "New package",
        "organization_id" => current_user.organization_id
      })
      |> then(&Package.changeset_for_create_gallery(package, &1))

    assign(
      socket,
      download_changeset: download_changeset,
      package_changeset: package_changeset,
      package_pricing:
        PackagePricing.changeset(
          package_pricing,
          params["package_pricing"] ||
            package_pricing_params(package)
        )
    )
  end

  defp package_pricing_params(package) do
    case package |> Map.get(:print_credits) do
      nil -> %{is_enabled: false}
      %Money{} = value -> %{is_enabled: Money.positive?(value)}
      _ -> %{}
    end
  end
end
