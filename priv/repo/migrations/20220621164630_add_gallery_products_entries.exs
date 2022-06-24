defmodule Picsello.Repo.Migrations.AddGalleryProductsEntries do
  use Ecto.Migration

  def change do
    execute(
      """
        insert into
        gallery_products (
            gallery_id,
            category_id,
            inserted_at,
            updated_at
          ) (
            select
              g.id as gallery_id,
              c.id as category_id,
              now(),
              now()
            from
              categories c
              join galleries g on true
              left join gallery_products gp on gp.category_id = c.id and gp.gallery_id = g.id
              where c.hidden = false and gp.id is null
          )
      """,
      ""
    )
  end
end
