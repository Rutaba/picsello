defmodule Picsello.Repo.Migrations.RemoveCategoryTemplates do
  use Ecto.Migration

  def up do
    alter table(:gallery_products) do
      add(:category_id, references(:categories))
    end

    execute("""
    update gallery_products
    set category_id = category_templates.category_id
    from category_templates
    where gallery_products.category_template_id = category_templates.id
    """)

    alter table(:gallery_products) do
      modify(:category_id, :integer, null: false)
      remove(:category_template_id)
    end

    alter table(:categories) do
      add(:frame_image, :string)
    end

    drop(table(:category_templates))
  end

  def down do
    create table(:category_templates) do
      add(:name, :string)
      add(:title, :string)
      add(:corners, {:array, :integer})
      add(:category_id, references(:categories, on_delete: :nothing))
      add(:price, :integer, null: false)

      timestamps()
    end

    create(index(:category_templates, [:category_id]))

    execute("""
    insert into category_templates (name,corners,category_id,title,price,inserted_at,updated_at)
    select name, '{}', id, name, 0, now(), now() from categories
    """)

    alter table(:gallery_products) do
      add(:category_template_id, references(:category_templates))
    end

    execute("""
    update gallery_products
    set category_template_id = category_templates.id
    from category_templates
    where category_templates.category_id = gallery_products.category_id
    """)

    alter table(:gallery_products) do
      remove(:category_id, references(:category_templates))
    end

    alter table(:categories) do
      remove(:frame_image)
    end
  end
end
