defmodule SendgridClient do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.sendgrid.com/v3")

  plug(Tesla.Middleware.Headers, [
    {"authorization", "Bearer #{config()[:api_key]}"}
  ])

  plug(Tesla.Middleware.JSON)

  def send_mail(body) do
    post("/mail/send", body)
  end

  def get_template(template_id) do
    get("/templates/" <> template_id)
  end

  defp config, do: Application.get_env(:picsello, Picsello.Mailer)

  def marketing_template_id(), do: config()[:marketing_template]

  def marketing_unsubscribe_id() do
    {id, _} = config()[:marketing_unsubscribe_id] |> Integer.parse()
    id
  end
end
