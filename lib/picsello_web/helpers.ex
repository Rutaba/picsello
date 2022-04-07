defmodule PicselloWeb.Helpers do
  @moduledoc "This module is used to define functions that can be accessed outside *Web"
  alias PicselloWeb.Endpoint
  alias PicselloWeb.Router.Helpers, as: Routes

  def jobs_url(), do: Routes.job_url(Endpoint, :jobs)
  def job_url(id), do: Routes.job_url(Endpoint, :jobs, id)
  def lead_url(id), do: Routes.job_url(Endpoint, :leads, id)
  def inbox_thread_url(id), do: Routes.inbox_url(Endpoint, :show, id)

  defdelegate dyn_gettext(key), to: PicselloWeb.Gettext
end
