defmodule Picsello.Repo.Migrations.AddCurrenciesTable do
  use Ecto.Migration

  @csv_file "./priv/repo/csv/currencies.csv"

  def up do
    # create table(:currencies, primary_key: false) do
    #   add(:code, :string, primary_key: true)
    # end

    # @csv_file
    # |> File.stream!()
    # |> CSV.decode!()
    # |> Enum.each(fn [currency] ->
    #   execute("INSERT INTO currencies (code) VALUES ('#{currency}')")
    # end)
  end

  def down do
    drop(table(:currencies, primary_key: false))
  end
end
