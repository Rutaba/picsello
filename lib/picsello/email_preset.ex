defmodule Picsello.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Picsello.Repo.CustomMacros

  @job_states ~w(post_shoot booking_proposal job lead)a

  schema "email_presets" do
    field :body_template, :string
    field :job_state, Ecto.Enum, values: @job_states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string
    field :position, :integer

    timestamps type: :utc_datetime
  end

  def job_states(), do: @job_states

  def for_job(%{id: job_id}) do
    from(preset in __MODULE__,
      join: job in Picsello.Job,
      on: job.type == preset.job_type and job.id == ^job_id,
      join: status in assoc(job, :job_status),
      join:
        shoot in subquery(
          from(
            shoot in Picsello.Shoot,
            where: shoot.starts_at <= now() and shoot.job_id == ^job_id,
            select: %{past_count: count(shoot.id)}
          )
        ),
      on: true,
      where:
        (status.is_lead and preset.job_state == :lead) or
          (not status.is_lead and
             ((preset.job_state == :job and shoot.past_count == 0) or
                (preset.job_state == :post_shoot and shoot.past_count > 0))),
      order_by: :position
    )
    |> Picsello.Repo.all()
  end

  defmodule Resolver do
    @moduledoc "resolves mustache variables"

    defstruct [:job, :helpers]

    def new(job, helpers), do: %__MODULE__{job: job, helpers: helpers}

    def fetch(%__MODULE__{} = resolver, key) do
      case Map.fetch(vars(), key) do
        {:ok, f} -> {:ok, f.(resolver)}
        err -> err
      end
    end

    defp client(%__MODULE__{job: job}), do: Picsello.Repo.preload(job, :client).client

    defp organization(%__MODULE__{} = resolver),
      do: resolver |> client() |> Picsello.Repo.preload(:organization) |> Map.get(:organization)

    defp photographer(%__MODULE__{} = resolver),
      do: resolver |> organization() |> Picsello.Repo.preload(:user) |> Map.get(:user)

    defp current_proposal(%__MODULE__{job: job}),
      do:
        job
        |> Picsello.Repo.preload(:booking_proposals)
        |> Map.get(:booking_proposals)
        |> Enum.sort_by(& &1.updated_at, DateTime)
        |> List.last()

    defp next_shoot(%__MODULE__{job: job}) do
      job
      |> Picsello.Repo.preload(:shoots)
      |> Map.get(:shoots)
      |> Enum.filter(&(DateTime.compare(&1.starts_at, DateTime.utc_now()) == :gt))
      |> Enum.sort_by(& &1.starts_at, DateTime)
      |> case do
        [next_shoot | _rest] -> next_shoot
        _ -> nil
      end
    end

    defp strftime(%__MODULE__{helpers: helpers} = resolver, date, format) do
      resolver |> photographer() |> Map.get(:time_zone) |> helpers.strftime(date, format)
    end

    defp package(%__MODULE__{job: job}), do: Picsello.Repo.preload(job, :package).package

    defp noop(%__MODULE__{}), do: nil

    defp helpers(%__MODULE__{helpers: helpers}), do: helpers

    def vars,
      do: %{
        "brand_sentence" => &noop/1,
        "client_first_name" => &(&1 |> client() |> Map.get(:name) |> String.split() |> hd),
        "delivery_expectations_sentence" => &noop/1,
        "delivery_time" =>
          &with(
            %{turnaround_weeks: weeks} <- package(&1),
            do:
              helpers(&1).ngettext(
                "one week",
                "%{count} weeks",
                weeks
              )
          ),
        # handled in sendgrid template
        "email_signature" => &noop/1,
        "invoice_amount" =>
          &with(
            %Picsello.Package{} = package <- package(&1),
            do: Picsello.Package.remainder_price(package)
          ),
        "invoice_due_date" =>
          &with(
            %{job: job} <- &1,
            %DateTime{} = due_on <- Picsello.PaymentSchedules.remainder_due_on(job),
            do:
              strftime(
                &1,
                due_on,
                "%b %d, %Y"
              )
          ),
        "invoice_link" =>
          &with(
            %Picsello.BookingProposal{id: proposal_id} <- current_proposal(&1),
            do: Picsello.BookingProposal.url(proposal_id)
          ),
        "mini_session_link" => fn _job -> nil end,
        "photographer_cell" => &photographer(&1).onboarding.phone,
        "photography_company_s_name" => &organization(&1).name,
        "pricing_guide_link" => fn resolver ->
          helpers(resolver).profile_pricing_job_type_url(
            organization(resolver).slug,
            resolver.job.type
          )
        end,
        "review_link" => &noop/1,
        "session_date" =>
          &with(
            %{starts_at: starts_at} <- next_shoot(&1),
            do: strftime(&1, starts_at, "%b %d, %Y")
          ),
        "session_location" =>
          &with(
            %Picsello.Shoot{} = shoot <- next_shoot(&1),
            do: helpers(&1).shoot_location(shoot)
          ),
        "session_time" =>
          &with(
            %{starts_at: starts_at} <- next_shoot(&1),
            do: strftime(&1, starts_at, "%-I:%M %P")
          ),
        "view_proposal_button" =>
          &with(
            %Picsello.BookingProposal{id: proposal_id} <- current_proposal(&1),
            do: """
            <a style="display:inline-block;background:#1F1C1E;color:#ffffff;font-family:Be Vietnam, Arial;font-size:18px;font-weight:bold;line-height:120%;margin:0;text-decoration:none;text-transform:none;padding:20px 30px;mso-padding-alt:0px;border-radius:12px;"
               target="_blank"
               href="#{Picsello.BookingProposal.url(proposal_id)}">View Proposal</a>
            """
          ),
        "wardrobe_guide_link" => &noop/1,
        "wedding_questionnaire_2_link" => &noop/1
      }
  end

  def resolve_variables(%__MODULE__{} = preset, job, helpers) do
    resolver = Resolver.new(job, helpers)

    %{
      preset
      | body_template: Mustache.render(preset.body_template, resolver),
        subject_template: Mustache.render(preset.subject_template, resolver)
    }
  end
end
