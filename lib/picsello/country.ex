defmodule Picsello.Country do
  @moduledoc "countries for business address"
  use Ecto.Schema
  alias Picsello.Repo

  schema "countries" do
    field :code, :string
    field :name, :string
  end

  def all(), do: Repo.all(__MODULE__)
end
