defmodule PicselloWeb.FormHelpers do
  alias PicselloWeb.Router.Helpers, as: Routes

  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, opts \\ []) do
    class = classes(["invalid-feedback", Keyword.get_values(opts, :class)])

    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error),
        class: class,
        phx_feedback_for: input_name(form, field)
      )
    end)
  end

  @doc """
  Generates an input tag with error state.
  """
  def input(form, field, opts \\ []) do
    type = opts |> Keyword.get(:type, :text_input)

    opts =
      case type do
        :datetime_local_input ->
          time_zone = opts |> Keyword.get(:time_zone, "UTC")

          value =
            input_value(form, field)
            |> format_datetime(time_zone)

          opts |> Keyword.put(:value, value)

        _ ->
          opts
      end

    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}

    input_opts =
      [
        phx_feedback_for,
        class:
          classes(["text-input", Keyword.get_values(opts, :class)], %{
            "text-input-invalid" => form.errors[field]
          })
      ] ++ Keyword.drop(opts, [:class, :type])

    apply(Phoenix.HTML.Form, type, [form, field, input_opts])
  end

  defp format_datetime(%DateTime{} = value, zone),
    do: value |> DateTime.shift_zone!(zone) |> Calendar.strftime("%Y-%m-%dT%H:%M")

  defp format_datetime("", _zone), do: nil

  defp format_datetime("" <> value, zone) do
    {:ok, value, _} = (value <> ":00Z") |> DateTime.from_iso8601()
    format_datetime(value, zone)
  end

  defp format_datetime(_, _), do: nil

  def label_for(form, field, opts \\ []) do
    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}
    label_text = Keyword.get(opts, :label) || humanize(field)

    label_opts = [
      phx_feedback_for,
      class:
        classes(["input-label" | Keyword.get_values(opts, :class)], %{
          "input-label-invalid" => form.errors[field]
        })
    ]

    label form, field, label_opts do
      [label_text, " ", error_tag(form, field)]
    end
  end

  def labeled_input(form, field, opts \\ []) do
    label_opts = [label: Keyword.get(opts, :label), class: Keyword.get(opts, :label_class)]

    input_opts =
      [
        class: opts |> Keyword.get(:input_class) |> classes()
      ] ++
        Keyword.drop(opts, [:wrapper_class, :input_class, :label_class, :label])

    content_tag :div,
      class: classes([Keyword.get_values(opts, :wrapper_class), "flex", "flex-col"]) do
      [
        label_for(form, field, label_opts),
        input(form, field, input_opts)
      ]
    end
  end

  def select_field(form, field, options, opts \\ []) do
    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}

    value = input_value(form, field)

    select_opts =
      [
        phx_feedback_for,
        class:
          classes(["select" | Keyword.get_values(opts, :class)], %{
            "select-invalid" => form.errors[field],
            "select-prompt" => !value || value == ""
          })
      ] ++
        Keyword.drop(opts, [:class])

    Phoenix.HTML.Form.select(form, field, options, select_opts)
  end

  def labeled_select(form, field, options, opts \\ []) do
    label_opts = [label: Keyword.get(opts, :label)]

    select_opts =
      [
        class: opts |> Keyword.get(:select_class) |> classes()
      ] ++
        Keyword.drop(opts, [:wrapper_class, :select_class, :label])

    content_tag :div,
      class: classes([Keyword.get_values(opts, :wrapper_class), "flex", "flex-col"]) do
      [
        label_for(form, field, label_opts),
        select_field(form, field, options, select_opts)
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
    content_tag(:svg, opts) do
      tag(:use, "xlink:href": Routes.static_path(conn, "/images/icons.svg#" <> name))
    end
  end

  def classes(constants), do: classes(constants, %{})

  def classes(nil, optionals), do: classes([], optionals)

  def classes("" <> constant, optionals) do
    classes([constant], optionals)
  end

  def classes(constants, optionals) do
    [
      constants,
      optionals
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    ]
    |> Enum.concat()
    |> Enum.join(" ")
  end
end
