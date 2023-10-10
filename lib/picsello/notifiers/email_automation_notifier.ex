defmodule Picsello.Notifiers.EmailAutomationNotifier do
  @moduledoc false

  @callback deliver_automation_email_job(map(), map(), tuple(), atom(), any()) ::
              {:error, binary() | map()} | {:ok, map()}
  @callback deliver_automation_email_gallery(map(), map(), tuple(), atom(), any()) ::
              {:error, binary() | map()} | {:ok, map()}
  @callback deliver_automation_email_order(map(), map(), tuple(), atom(), any()) ::
              {:error, binary() | map()} | {:ok, map()}

  def deliver_automation_email_job(email_preset, job, schema, state, helpers),
    do: impl().deliver_automation_email_job(email_preset, job, schema, state, helpers)

  def deliver_automation_email_gallery(email_preset, gallery, schema, state, helpers),
    do: impl().deliver_automation_email_gallery(email_preset, gallery, schema, state, helpers)

  def deliver_automation_email_order(email_preset, order, schema, state, helpers),
    do: impl().deliver_automation_email_order(email_preset, order, schema, state, helpers)

  defp impl, do: Application.get_env(:picsello, :email_automation_notifier)
end
