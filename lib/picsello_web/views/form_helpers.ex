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
        :number_input ->
          opts |> Keyword.put_new(:inputmode, "numeric") |> Keyword.put_new(:pattern, "[0-9]*")

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
    assigns = Enum.into(assigns, %{class: class})

    ~H"""
    <label class={@class} phx-feedback-for={input_name(@form, @field)} for={input_id(@form, @field)}><%= render_slot @inner_block %></label>
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
    {label_opts, opts} = Keyword.split(opts, [:label, :optional, :label_class])

    select_opts =
      [
        class: opts |> Keyword.get(:select_class) |> classes()
      ] ++
        Keyword.drop(opts, [:wrapper_class, :select_class])

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
        name: :link,
        show_checkbox: true
      })

    ~H"""
    <label class={"flex flex-col #{@class}"}>
        <p class="py-2 font-extrabold"><%= @label %> <i class="italic font-light">(No worries if you don’t have one)</i></p>

        <div class="relative flex flex-col">
          <%= input @form, @name,
              type: :url_input,
              phx_debounce: "500",
              disabled: input_value(@form, @name) == true,
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

  def date_picker_field(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: "flex flex-col",
        form: nil,
        field: nil,
        input_label: nil,
        input_placeholder: "Select date…",
        input_class: "text-input w-full",
        data_min_date: nil,
        data_time_only: nil,
        data_custom_display_format: nil,
        data_custom_date_format: nil,
        data_time_picker: nil,
        disabled: nil,
        data_time_zone: nil
      })

    ~H"""
    <div class={@class}>
      <%= if @input_label do %>
      <.input_label form={@form} class="input-label" field={@field}>
        <%= @input_label %> <%= error_tag(@form, @field) %>
      </.input_label>
      <% end %>
      <div class="flatpickr" phx-update="ignore" phx-hook="DatePicker" id={@id} data-min-date={@data_min_date} data-time-only={@data_time_only} data-time-picker={@data_time_picker} data-custom-display-format={@data_custom_display_format} data-custom-date-format={@data_custom_date_format} data-time-zone={@data_time_zone}>
        <%= text_input @form, @field, class: @input_class, placeholder: @input_placeholder, data_input: true, disabled: @disabled %>
      </div>
    </div>
    """
  end
end
