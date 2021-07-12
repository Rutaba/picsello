defmodule Bamboo.SendgridLocalAdapter do
  @moduledoc """
  Replaces the body of the email with the sendgrid template info,
  then delegates to Bamboo.LocalAdapter
  """

  alias Bamboo.{Email, LocalAdapter}

  @behaviour Bamboo.Adapter

  def deliver(%Email{private: %{send_grid_template: send_grid}} = email, config) do
    data = send_grid |> inspect(pretty: true)

    email
    |> Email.html_body("""
    <div>
      <h1>Sendgrid Template</h1>
      <pre>#{data}</pre>
    </div>
    """)
    |> LocalAdapter.deliver(config)
  end

  defdelegate handle_config(config), to: LocalAdapter

  defdelegate supports_attachments?, to: LocalAdapter
end
