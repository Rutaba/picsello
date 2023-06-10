defmodule PicselloWeb.EmailAutomationLive.Shared do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.{EmailPresets.EmailPreset, EmailAutomation}

  def make_email_presets_options(email_presets) do
    email_presets
    |> Enum.map(fn %{id: id, name: name} -> {name, id} end)
  end

  def email_preset_changeset(socket, email_preset, params \\ nil) do
    email_preset_changeset = build_email_changeset(email_preset, params)
    body_template = current(email_preset_changeset) |> Map.get(:body_template)

    if params do
      socket
    else
      socket
      |> push_event("quill:update", %{"html" => body_template})
    end
    |> assign(email_preset_changeset: email_preset_changeset)
  end

  def assign_automation_pipelines(
        %{assigns: %{current_user: current_user, selected_job_type: selected_job_type}} = socket
      ) do
    automation_pipelines =
      EmailAutomation.get_all_pipelines_emails(current_user.organization_id, selected_job_type.id)
      |> assign_category_pipeline_count()

    socket |> assign(:automation_pipelines, automation_pipelines)
  end

  defp assign_category_pipeline_count(automation_pipelines) do
    automation_pipelines
    |> Enum.map(fn %{subcategories: subcategories} = category ->
      total_emails_count =
        subcategories
        |> Enum.reduce(0, fn subcategory, acc ->
          email_count =
            Enum.reduce(subcategory.pipelines, 0, fn pipeline, acc ->
              acc + Enum.count(pipeline.emails)
            end)

          email_count + acc
        end)

      Map.put(category, :total_emails_count, total_emails_count)
    end)
  end

  def build_email_changeset(email_preset, params) do
    if params do
      params
    else
      email_preset
      |> Map.put(:template_id, email_preset.id)
      |> prepare_email_preset_params()
    end
    |> EmailPreset.changeset()
  end

  defp prepare_email_preset_params(email_preset) do
    email_preset
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end

  def make_options(changeset, job_types) do
    job_types
    |> Enum.map(fn option ->
      Map.put(option, :label, String.capitalize(option.label))
    end)
  end

  def validate?(false, _), do: false

  def validate?(true, job_types) do
    Enum.any?(job_types, &Map.get(&1, :selected, false))
  end

  def explode_hours(hours) do
    year = 365 * 24
    month = 30 * 24
    sign = if hours > 0, do: "+", else: "-"
    hours = make_positive_number(hours)

    cond do
      rem(hours, year) == 0 -> %{count: trunc(hours / year), calendar: "Year", sign: sign}
      rem(hours, month) == 0 -> %{count: trunc(hours / month), calendar: "Month", sign: sign}
      rem(hours, 24) == 0 -> %{count: trunc(hours / 24), calendar: "Day", sign: sign}
      true -> %{count: hours, calendar: "Hour", sign: sign}
    end
  end

  defp make_positive_number(no), do: if(no > 0, do: no, else: -1 * no)
end
