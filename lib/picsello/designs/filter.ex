defmodule Picsello.Designs.Filter do
  @moduledoc """
    Create and apply card design filter options
  """
  import Ecto.Query, only: [from: 2]
  alias Picsello.Repo

  defmodule Orientation do
    @moduledoc """
      filter to portrait or landscape - if both are in the query.
    """

    def load_options(designs_query) do
      from(design in designs_query,
        select:
          {fragment("jsonb_path_exists(?, '$.faces[*] \\? (@.height > @.width)')", design.api),
           count(design.id)},
        group_by: 1
      )
      |> Repo.all()
      |> Enum.into(%{})
      |> case do
        %{true: portrait_count, false: landscape_count}
        when portrait_count > 0 and landscape_count > 0 ->
          [
            %{name: "Portrait", id: "portrait"},
            %{name: "Landscape", id: "landscape"}
          ]

        _ ->
          []
      end
    end

    def query(query, ["portrait"]) do
      from(
        designs in query,
        where:
          fragment("jsonb_path_exists(?, '$.faces[*] \\? (@.height > @.width)')", designs.api)
      )
    end

    def query(query, _) do
      from(
        designs in query,
        where:
          fragment("jsonb_path_exists(?, '$.faces[*] \\? (@.height < @.width)')", designs.api)
      )
    end
  end

  defmodule Foil do
    @moduledoc """
      filter to foil or no foil - if both are in the query.
    """
    def load_options(designs_query) do
      from(design in designs_query,
        select:
          {fragment("jsonb_path_match(?, '$.metadata.hasFoils')", design.api), count(design.id)},
        group_by: 1
      )
      |> Repo.all()
      |> Enum.into(%{})
      |> case do
        %{true: foil_count, false: no_foil_count}
        when foil_count > 0 and no_foil_count > 0 ->
          [
            %{name: "Has Foil", id: "foil"},
            %{name: "No Foil", id: "no_foil"}
          ]

        _ ->
          []
      end
    end

    def query(query, ["foil"]) do
      from(
        designs in query,
        where: fragment("jsonb_path_match(?, '$.metadata.hasFoils')", designs.api)
      )
    end

    def query(query, _) do
      from(
        designs in query,
        where:
          fragment("jsonb_path_exists(?, '$.metadata.hasFoils \\? (@ == false)')", designs.api)
      )
    end
  end

  defmodule Tag do
    @moduledoc """
      filter to designs with all of the chosen tags.
      only presents options for tags used more than once.
    """

    def load_options(designs_query) do
      from(design in designs_query,
        join: tag in fragment("jsonb_array_elements_text(? -> 'metadata' -> 'tags')", design.api),
        where: fragment("length(?)", tag) > 0,
        group_by: 1,
        select: fragment("?", tag),
        order_by: [desc: count(design.id)],
        having: count(design.id) > 1
      )
      |> Repo.all()
      |> Enum.map(&%{name: &1, id: &1})
    end

    def query(query, tags) do
      from(
        designs in query,
        where: fragment("? -> 'metadata' -> 'tags' \\?& ?", designs.api, ^tags)
      )
    end
  end

  defmodule Color do
    @moduledoc """
      filter to designs with a similar color.
      color similarity calculated via [Euclidean distance](https://en.wikipedia.org/wiki/Color_difference#Euclidean).
    """
    # acceptable distance between colors
    @threshold 60

    import Ecto.Query, only: [or_where: 3, from: 2]
    import Picsello.Repo.CustomMacros

    def load_options(designs_query) do
      from(design in designs_query,
        join: themes in fragment("jsonb_each(? -> 'themes')", design.api),
        group_by: [1, 2, 3],
        select: %{
          color: {
            themes.value ~> "swatch" ~> 0 |> type(:float),
            themes.value ~> "swatch" ~> 1 |> type(:float),
            themes.value ~> "swatch" ~> 2 |> type(:float)
          },
          name: themes.key |> jsonb_agg() ~>> 0
        },
        where: fragment("jsonb_array_length(? -> 'swatch')", themes.value) == 3,
        order_by: [desc: count(design.id)]
      )
      |> Repo.all()
      |> Enum.reduce([], fn
        %{color: color, name: name}, color_groups ->
          {near, far} = Enum.split_with(color_groups, &(distance(color, &1.color) < @threshold))
          [%{name: name, color: average([color | Enum.map(near, & &1.color)])} | far]
      end)
      |> Enum.map(fn %{name: name, color: {r, g, b} = color} ->
        %{name: name, swatch: color, id: "#{r}-#{g}-#{b}"}
      end)
    end

    def query(query, colors) do
      ids =
        for color <- colors,
            reduce:
              from(
                design in Picsello.Design,
                join: swatches in jsonb_path_query(design.api, "$.themes.*.swatch"),
                select: design.id,
                distinct: true
              ) do
          query ->
            [r, g, b] = color |> String.split("-") |> Enum.map(&String.to_integer/1)

            or_where(
              query,
              [_, swatches],
              fragment(
                "|/((?) ^2 + (?) ^2 + (?) ^2)",
                (swatches ~> 0 |> type(:float)) - ^r,
                (swatches ~> 1 |> type(:float)) - ^g,
                (swatches ~> 2 |> type(:float)) - ^b
              ) < @threshold
            )
        end

      from(design in query, where: design.id in subquery(ids))
    end

    defp distance({r1, g1, b1}, {r2, g2, b2}) do
      Float.pow(
        Float.pow(r2 - r1, 2) + Float.pow(g2 - g1, 2) + Float.pow(b2 - b1, 2),
        0.5
      )
    end

    defp average([{r, g, b}]), do: {trunc(r), trunc(g), trunc(b)}

    defp average(colors) do
      Enum.reduce(colors, fn c1, c2 ->
        [r, g, b] =
          c1
          |> Tuple.to_list()
          |> Enum.zip(Tuple.to_list(c2))
          |> Enum.map(fn {p1, p2} -> ((p1 + p2) / 2.0) |> round() |> trunc() end)

        {r, g, b}
      end)
    end
  end

  @filters [
    %{module: Orientation, name: "Orientation", id: "orientation"},
    %{module: Foil, name: "Foil", id: "foil"},
    %{module: Tag, name: "Type", id: "tag"},
    %{module: Color, name: "Color", id: "color"}
  ]

  def load(designs_query) do
    Enum.flat_map(@filters, &load_options(designs_query, &1))
  end

  def open(filters, target_filter_id) do
    for %{id: filter_id} = filter <- filters do
      case filter_id do
        ^target_filter_id -> Map.update!(filter, :open, &not/1)
        _ -> filter
      end
    end
  end

  def close_all(filters) do
    for filter <- filters do
      %{filter | open: false}
    end
  end

  defp load_options(designs_query, %{module: module} = config) do
    case module.load_options(designs_query) do
      [] ->
        []

      options ->
        [
          config
          |> Map.drop([:module])
          |> Map.merge(%{options: Enum.map(options, &Map.put(&1, :checked, false)), open: false})
        ]
    end
  end

  def update(filters, selections) do
    {remove, selections} = Map.pop(selections, "remove", %{})

    for %{id: filter_id, options: options} = filter <- filters do
      selections = Map.get(selections, filter_id, [])
      remove = Map.get(remove, filter_id, [])

      options =
        for %{id: option_id} = option <- options do
          %{option | checked: option_id in selections and option_id not in remove}
        end

      %{filter | options: options}
    end
  end

  def to_params(filters) do
    for %{id: filter_id, options: options} <- filters,
        %{checked: true, id: option_id} <- options,
        reduce: %{} do
      acc -> Map.update(acc, filter_id, [option_id], &[option_id | &1])
    end
  end

  def query(designs_query, filter) do
    for %{id: filter_id, options: options} <- filter,
        %{id: ^filter_id, module: filter_module} <- @filters,
        reduce: designs_query do
      acc ->
        for(%{checked: true, id: id} <- options, do: id)
        |> case do
          [] -> acc
          checked_options when length(options) == length(checked_options) -> acc
          options -> filter_module.query(acc, options)
        end
    end
  end
end
