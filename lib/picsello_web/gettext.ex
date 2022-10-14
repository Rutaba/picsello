defmodule PicselloWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      import PicselloWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext, otp_app: :picsello

  def dyn_gettext(domain \\ "picsello", value) do
    Gettext.dgettext(__MODULE__, domain, value)
  end

  def action_name(action, inflection \\ :singular) do
    case {action, inflection} do
      {:jobs, :singular} -> "Job"
      {:jobs, :plural} -> "Jobs"
      {:leads, :singular} -> "Lead"
      {:leads, :plural} -> "Leads"
      {:galleries, :singular} -> "Gallery"
      {:galleries, :plural} -> "Galleries"
      _ -> action |> Atom.to_string() |> dyn_gettext()
    end
  end
end
