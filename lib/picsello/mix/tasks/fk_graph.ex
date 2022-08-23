defmodule Mix.Tasks.FkGraph do
  @moduledoc "graph(viz) database foreign keys"

  use Mix.Task

  @out_file "doc/fk_graph.svg"

  @shortdoc "graph(viz) database foreign keys"
  def run(_) do
    case System.find_executable("dot") do
      nil ->
        [:red, "install graphviz (brew install graphviz)"]
        |> IO.ANSI.format()
        |> IO.puts()

      _ ->
        create_dot() |> write_svg()

        [:green, "foreign key graph written to #{@out_file}"]
        |> IO.ANSI.format()
        |> IO.puts()
    end
  end

  defp create_dot() do
    Mix.Task.run("app.start")

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
        order by source
      """)

    relations =
      for {{table, refs}, color} <-
            rows
            |> Enum.group_by(&hd/1)
            |> Enum.zip(Stream.cycle(~w[red orange yellow green blue violet])),
          refs <- Enum.map(refs, &List.last/1),
          into: "",
          do: "#{table} -> {#{refs}} [color=dark#{color}];"

    """
      digraph fks {
      node [shape=box];
      #{relations}
      }
    """
  end

  defp write_svg(dot) do
    port = Port.open({:spawn, "dot -Tsvg"}, [:binary])
    send(port, {self(), {:command, dot}})

    svg = loop(port, "")

    @out_file |> Path.dirname() |> File.mkdir_p()
    File.write(@out_file, svg)

    Port.close(port)
  end

  defp loop(port, svg) do
    receive do
      {^port, {:data, data}} ->
        svg = svg <> data

        if valid_xml?(svg) do
          svg
        else
          loop(port, svg)
        end
    end
  end

  defp valid_xml?(string) do
    try do
      string |> String.to_charlist() |> :xmerl_scan.string(quiet: true)
      true
    catch
      _, _ -> false
    end
  end
end
