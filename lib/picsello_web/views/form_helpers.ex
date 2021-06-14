defmodule PicselloWeb.FormHelpers do
  alias PicselloWeb.Router.Helpers, as: Routes

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
  Generates an input tag with error state.
  """
  def input(form, field, opts \\ []) do
    type = Phoenix.HTML.Form.input_type(form, field)

    has_error = form.errors[field]

    inputs_classes =
      Keyword.get_values(opts, :class) ++
        ["text-input"] ++ if has_error, do: ["text-input-invalid"], else: []

    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}

    input_opts =
      [
        phx_feedback_for,
        class: Enum.join(inputs_classes, " ")
      ] ++ Keyword.drop(opts, [:class])

    apply(Phoenix.HTML.Form, type, [form, field, input_opts])
  end

  @doc """
  Generates an input tag with error state.
  """
  def label_for(form, field, opts \\ []) do
    has_error = form.errors[field]
    label_classes = ["input-label"] ++ if has_error, do: ["input-label-invalid"], else: []
    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}
    label_text = Keyword.get(opts, :label) || humanize(field)
    label_opts = [phx_feedback_for, class: Enum.join(label_classes, " ")]

    label form, field, label_opts do
      [label_text, " ", error_tag(form, field)]
    end
  end

  @doc """
  Generates a labeled input tag with inlined errors.
  """
  def labeled_input(form, field, opts \\ []) do
    wrapper_classes = Keyword.get_values(opts, :wrapper_class) ++ ["flex", "flex-col"]

    wrapper_opts = [class: Enum.join(wrapper_classes, " ")]

    label_opts = [label: Keyword.get(opts, :label)]

    input_opts =
      [
        class: Keyword.get(opts, :input_class)
      ] ++
        Keyword.drop(opts, [:wrapper_class, :input_class, :label])

    content_tag :div, wrapper_opts do
      [
        label_for(form, field, label_opts),
        input(form, field, input_opts)
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

  def icon_tag(conn, name, opts \\ []) do
    classes = Keyword.get(opts, :class, "")

    content_tag(:svg, class: classes) do
      tag(:use, "xlink:href": Routes.static_path(conn, "/images/icons.svg#" <> name))
    end
  end
end
