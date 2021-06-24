defmodule Mix.Tasks.FkGraph do
  @moduledoc "graph(viz) database foreign keys"

  use Mix.Task

  @shortdoc "graph(viz) database foreign keys"
  def run(_) do
    Mix.Task.run("app.start")
    Logger.configure(level: :warn)

    {:ok, %{rows: rows}} =
      Picsello.Repo.query("""
        select
          source.relname as source,
          string_agg(dest.relname, ' ') as dests
        from pg_catalog.pg_constraint as fk
        join pg_catalog.pg_class as source on source.oid = fk.conrelid
        join pg_catalog.pg_class as dest   on   dest.oid = fk.confrelid
        where contype = 'f'::char
        group by source
      """)

    relations =
      for [table, refs] <- rows, reduce: "" do
        acc -> "#{acc}\n\t#{table} -> {#{refs}};"
      end

    IO.puts("""
      digraph fks {
      \tlayout=neato;
      \tnodesep=1;
      \tnode [shape=box];
      #{relations}
      }
    """)
  end
end
