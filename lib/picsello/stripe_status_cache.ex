defmodule Picsello.StripeStatusCache do
  @moduledoc false

  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def current_for(account_id, fetch_fun) do
    cached_value = Agent.get(__MODULE__, &Map.get(&1, account_id, :loading))

    caller_pid = self()

    update_status = fn status ->
      Agent.update(__MODULE__, &Map.put(&1, account_id, status))
      send(caller_pid, {:stripe_status, status})
    end

    Task.start_link(fn ->
      case fetch_fun.() do
        :error when cached_value == :loading ->
          update_status.(:error)

        status when status != cached_value ->
          update_status.(status)

        _e ->
          nil
      end
    end)

    cached_value
  end
end
