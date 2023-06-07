defmodule PicselloWeb.EmailAutomationLive.Shared do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.{EmailPresets.EmailPreset}

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
    job_types |> Enum.map(fn option ->
      Map.put(option, :label, String.capitalize(option.label))
    end)
  end

  def validate?(false, _), do: false
  def validate?(true, job_types) do
    Enum.any?(job_types, &Map.get(&1, :selected, false))
  end
end
