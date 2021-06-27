defmodule Picsello.Sandbox do
  @moduledoc "custom async sandbox"

  defmodule PidMap do
    @moduledoc "track the test pid <-> socket pid associations"
    use Agent

    def start() do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def assign(owner_pid, child_pid) do
      Agent.update(__MODULE__, fn pid_map ->
        Map.put(pid_map, child_pid, owner_pid)
      end)
    end

    def owner_pid(child_pid) do
      Agent.get(__MODULE__, &Map.get(&1, child_pid, child_pid))
    end
  end

  def allow(repo, owner_pid, child_pid) do
    PidMap.assign(owner_pid, child_pid)
    # Delegate to the Ecto sandbox
    Ecto.Adapters.SQL.Sandbox.allow(repo, owner_pid, child_pid)
  end

  defmodule BambooAdapter do
    @moduledoc "send email to the test pid"
    def deliver(email, _config) do
      to_pid = Picsello.Sandbox.PidMap.owner_pid(self())

      email = clean_assigns(email)

      send(to_pid, {:delivered_email, email})

      {:ok, email}
    end

    defdelegate handle_config(config), to: Bamboo.TestAdapter
    defdelegate clean_assigns(email), to: Bamboo.TestAdapter
  end
end
