defmodule Picsello.Repo.Migrations.AddCountriesTable do
  use Ecto.Migration

  @csv_file "./priv/repo/csv/countries.csv"
  def up do
    # create table(:countries, primary_key: false) do
    #   add(:code, :string)
    #   add(:name, :string, primary_key: true)
    # end

    # @csv_file
    # |> File.stream!()
    # |> Stream.drop(1)
    # |> CSV.decode!()
    # |> Enum.each(fn [code, name] ->
    #   execute("INSERT INTO countries (code, name) VALUES ('#{code}', '#{name}')")
    # end)
  end

  def down do
    # drop(table(:countries))
  end
end
