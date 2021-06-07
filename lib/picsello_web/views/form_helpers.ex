defmodule PicselloWeb.FormHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error),
        class: "invalid-feedback",
        phx_feedback_for: input_name(form, field)
      )
    end)
  end

  @doc """
  Generates a labeled input tag with inlined errors.
  """
  def input(form, field, opts \\ []) do
    type = Phoenix.HTML.Form.input_type(form, field)

    has_error = form.errors[field]

    wrapper_classes =
      Keyword.get_values(opts, :wrapper_class) ++
        ["flex", "flex-col"] ++ if has_error, do: ["error"], else: []

    inputs_classes = Keyword.get_values(opts, :input_class) ++ ["text-input"]

    wrapper_opts = [class: Enum.join(wrapper_classes, " ")]

    input_opts =
      [class: Enum.join(inputs_classes, " ")] ++
        Keyword.drop(opts, [:wrapper_class, :input_class])

    label_text = Keyword.get(opts, :label) || humanize(field)

    content_tag :div, wrapper_opts do
      [
        label form, field, class: "input-label" do
          [label_text, " ", error_tag(form, field)]
        end,
        apply(Phoenix.HTML.Form, type, [form, field, input_opts])
      ]
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(PicselloWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PicselloWeb.Gettext, "errors", msg, opts)
    end
  end
end
