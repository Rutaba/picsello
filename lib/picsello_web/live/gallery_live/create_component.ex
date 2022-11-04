defmodule PicselloWeb.GalleryLive.CreateComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  alias Picsello.{
    Job,
    Jobs,
    Package,
    Packages,
    Packages.Download,
    Packages.PackagePricing,
    Galleries.Gallery,
    Galleries,
    Repo
  }

  alias Ecto.Multi
  alias Ecto.Changeset

  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]

  import PicselloWeb.PackageLive.Shared,
    only: [digital_download_fields: 1, print_credit_fields: 1, current: 1]

  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @steps [:details, :pricing]

  @impl true
  def update(%{current_user: %{organization: %{profile: profile}}} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:job_id, nil)
    |> assign_new(:package, fn -> %Package{shoot_count: 1, contract: nil} end)
    |> assign_new(:package_pricing, fn -> %PackagePricing{} end)
    |> assign(templates: [], step: :details, steps: @steps)
    |> assign_package_changesets()
    |> assign_job_changeset(%{"client" => %{}, "shoots" => [%{"starts_at" => nil}]})
    |> assign(:job_types, (profile.job_types ++ [Picsello.JobType.other_type()]) |> Enum.uniq())
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

  def handle_event("submit", %{"job" => job_params}, socket) do
    socket
    |> assign_job_changeset(job_params)
    |> assign(:step, :pricing)
    |> noreply()
  end

  def handle_event("submit", params, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign_package_changesets(params)
    |> then(fn %{assigns: %{changeset: changeset, package_changeset: package_changeset}} ->
      client = changeset |> Changeset.apply_changes() |> Map.get(:client)
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
          name: "New Gallery",
          job_id: job_id,
          status: "active",
          password: Gallery.generate_password()
        })
      end)
      |> Repo.transaction()
    end)
    |> case do
      {:error, :job, changeset, _} ->
        socket |> assign(:changeset, changeset) |> assign(:step, :details)

      {:error, :package, changeset, _} ->
        assign(socket, :package_changeset, changeset)

      {:ok, %{gallery: %{id: gallery_id}}} ->
        send(self(), {:gallery_created, %{gallery_id: gallery_id}})
        socket |> assign(:gallery_id, gallery_id)
    end
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <.steps step={@step} steps={@steps} target={@myself} />

      <h1 class="mt-2 mb-4 text-3xl">
        <span class="font-bold">Create a Gallery:</span>
        <%= if @step == :details, do: "General Details", else: "Pricing" %>
      </h1>

      <.form
        for={@changeset}
        let={f} phx_change={:validate}
        phx_submit={:submit}
        phx_target={@myself}
        id={"form-#{@step}"}
        >
        <input type="hidden" name="step" value={@step} />
        <.step name={@step} f={f} {assigns} />

        <.footer>
          <.step_button name={@step} form={f} is_valid={valid?(assigns)} myself={@myself} />
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">Cancel</button>
        </.footer>
      </.form>
    </div>
    """
  end

  def step(%{name: :details} = assigns) do
    assigns = assigns |> Enum.into(%{email: nil, name: nil, phone: nil})

    ~H"""
      <div class="px-1.5 grid grid-cols-2 gap-5">
        <%= inputs_for @f, :client, fn client_form -> %>
        <%= labeled_input client_form, :name, label: "Client Name", placeholder: "First and last name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500" %>
        <%= labeled_input client_form, :email, type: :email_input, label: "Client Email", placeholder: "email@example.com", phx_debounce: "500" %>
      <% end %>

      <%= inputs_for @f, :shoots, fn shoot_form -> %>
        <%= labeled_input shoot_form, :starts_at, type: :datetime_local_input, label: "Shoot Date", min: Date.utc_today(), time_zone: @current_user.time_zone %>
      <% end %>

      <%= hidden_input @f, :is_gallery_only, value: true %>
      <%= labeled_select @f, :type, @job_types, type: :telephone_input, label: "Type of Photography", prompt: "Select below", phx_debounce: "500"%>
      </div>
    """
  end

  def step(%{name: :pricing} = assigns) do
    ~H"""
      <div class="">
        <% package = form_for(@package_changeset, "#") %>

        <%= hidden_input package, :shoot_count, value: 1 %>
        <%= hidden_input package, :turnaround_weeks, value: 1 %>

        <.print_credit_fields f={package} package_pricing={@package_pricing} />

        <.digital_download_fields for={:create_gallery} package_form={package} download={@download} package_pricing={@package_pricing} />
        <%= if @job_id do %>
          <div id="set-job-cookie" data-job-id={@job_id} phx-hook="SetJobCookie">
          </div>
        <% end %>
    </div>
    """
  end

  defp valid?(%{step: :details, changeset: changeset}), do: changeset.valid?

  defp valid?(assigns) do
    Enum.all?(
      [assigns.download, assigns.package_pricing, assigns.package_changeset],
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
         %{assigns: %{current_user: %{organization_id: organization_id}}} = socket,
         params,
         action \\ nil
       ) do
    params
    |> put_in(["client", "organization_id"], organization_id)
    |> Job.create_changeset()
    |> Changeset.cast_assoc(:shoots, with: &Picsello.Shoot.changeset_for_create_gallery/2)
    |> Map.put(:action, action)
    |> then(&assign(socket, :changeset, &1))
  end

  def assign_package_changesets(
        %{
          assigns: %{
            package: package,
            package_pricing: package_pricing,
            current_user: current_user
          }
        } = socket,
        params \\ %{},
        action \\ nil
      ) do
    download_changeset =
      package
      |> Download.from_package()
      |> Download.changeset(params["download"] || %{})
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
      download: download_changeset,
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
