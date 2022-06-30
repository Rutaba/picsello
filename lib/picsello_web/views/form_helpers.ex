defmodule PicselloWeb.FormHelpers do
  use Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [classes: 1, classes: 2]

  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, opts \\ []) do
    {class, opts} = Keyword.pop_values(opts, :class)
    {prefix, _opts} = Keyword.pop(opts, :prefix, "")

    class = classes(["invalid-feedback"] ++ class)

    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(
      &content_tag(:span, String.trim("#{prefix} #{translate_error(&1)}"),
        class: class,
        phx_feedback_for: input_name(form, field)
      )
    )
  end

  @doc """
  Generates an input tag with error state.
  """
  def input(form, field, opts \\ []) do
    {type, opts} = Keyword.pop(opts, :type, :text_input)
    {classes, opts} = Keyword.pop_values(opts, :class)

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

    input_opts =
      opts ++
        [
          phx_feedback_for: input_name(form, field),
          class: classes(["text-input", classes], %{"text-input-invalid" => form.errors[field]})
        ]

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
    label_text = Keyword.get(opts, :label) || humanize(field)

    label_opts = [
      phx_feedback_for: input_name(form, field),
      class:
        classes(["input-label" | Keyword.get_values(opts, :class)], %{
          "input-label-invalid" => form.errors[field],
          "after:content-['(optional)'] after:text-xs after:ml-0.5 after:italic after:font-normal" =>
            Keyword.get(opts, :optional)
        })
    ]

    label form, field, label_opts do
      [label_text, " ", error_tag(form, field)]
    end
  end

  def input_label(assigns) do
    %{form: form, field: field, class: class} = assigns |> Enum.into(%{class: ""})

    class = classes([class], %{"input-label-invalid" => form.errors[field]})

    ~H"""
    <label class={class} phx-feedback-for={input_name(form,field)} for={input_id(form, field)}><%= render_block @inner_block %></label>
    """
  end

  def labeled_input(form, field, opts \\ []) do
    {label_opts, opts} = Keyword.split(opts, [:label, :optional, :label_class])

    input_opts =
      [class: opts |> Keyword.get(:input_class) |> classes()] ++
        Keyword.drop(opts, [:wrapper_class, :input_class])

    content_tag :div,
      class: classes(Keyword.get_values(opts, :wrapper_class) ++ ["flex", "flex-col"]) do
      [
        label_for(form, field, label_opts),
        input(form, field, input_opts)
      ]
    end
  end

  def select_field(form, field, options, opts \\ []) do
    phx_feedback_for = {:phx_feedback_for, input_name(form, field)}

    select_opts =
      [
        phx_feedback_for,
        class: classes(["select" | Keyword.get_values(opts, :class)])
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
      class:
        classes(
          [Keyword.get_values(opts, :wrapper_class), "flex", "flex-col"],
          select_invalid_classes(form, field)
        ) do
      [
        label_for(form, field, label_opts),
        select_field(form, field, options, select_opts)
      ]
    end
  end

  def select_invalid_classes(form, field) do
    value = input_value(form, field)

    %{
      "select-invalid" => form.errors[field],
      "select-prompt" => !value || value == ""
    }
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

  def website_field(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: "",
        placeholder: "www.mystudio.com",
        label: "What is your website URL?",
        name: :website,
        show_checkbox: true
      })

    ~H"""
    <label class={"flex flex-col #{@class}"}>
        <p class="py-2 font-extrabold"><%= @label %> <i class="italic font-light">(No worries if you don’t have one)</i></p>

        <div class="relative flex flex-col">
          <%= input @form, @name,
              type: :url_input,
              phx_debounce: "500",
              disabled: input_value(@form, :website) == true,
              placeholder: @placeholder,
              autocomplete: "url",
              novalidate: true,
              phx_hook: "PrefixHttp",
              class: "p-4" %>
          <%= error_tag @form, @name, class: "text-red-sales-300 text-sm", prefix: "Website URL" %>
        </div>
      </label>
    """
  end
end
