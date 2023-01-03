defmodule Picsello.Zapier.User do
  @moduledoc """
   module for communicating with zapier to handle user
   events to send to many different platforms
  """

  use Tesla
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BaseUrl, "https://hooks.zapier.com/hooks/catch")

  @doc "initial user creation so we can tell if they potentially didn't finish onboarding, can be omitted with missing env vars"
  def user_created_webhook(body) do
    if config()[:new_user_webhook_url] do
      post(config()[:new_user_webhook_url], body)
    end
  end

  @doc "user finished onboarding/stripe setup, can be omitted with missing env vars"
  def user_trial_created_webhook(body) do
    if config()[:trial_user_webhook_url] do
      post(config()[:trial_user_webhook_url], body)
    end
  end

  @doc "users trial is ending soon, can be omitted with missing env vars"
  def user_subscription_ending_soon_webhook(body) do
    if config()[:subscription_ending_user_webhook_url] do
      post(config()[:subscription_ending_user_webhook_url], body)
    end
  end

  defp config, do: Application.get_env(:picsello, :zapier)
end
