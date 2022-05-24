defmodule Picsello.Repo.Migrations.CreateContracts do
  use Ecto.Migration

  def change do
    create table(:contracts) do
      add :name, :string, null: false
      add :content, :text, null: false
      add :organization_id, references(:organizations, on_delete: :nothing)
      add :job_type, references(:job_types, column: :name, type: :string)
      add :job_id, references(:jobs, on_delete: :nothing)
      add :contract_template_id, references(:contracts, on_delete: :nothing)

      timestamps()
    end

    # organization_id job_id
    # 1               1    =  invalid -- cannot both *be* a template and *have* a template
    # 1               0    =  valid -- contract template
    # 0               1    =  valid -- contract from job
    # 0               0    =  valid -- default picsello contract
    create(
      constraint("contracts", "templates_cannot_have_org_id_and_job_id",
        check: "((organization_id is not null)::integer + (job_id is not null)::integer) < 2"
      )
    )

    # organization_id job_type
    # 1               1    =  valid -- job_type is required when organization_id is present
    # 1               0    =  invalid
    # 0               1    =  invalid
    # 0               0    =  valid
    create(
      constraint("contracts", "templates_must_have_types",
        check: "((organization_id is not null)::integer + (job_type is not null)::integer) != 1"
      )
    )

    # job_id contract_template_id
    # 1      1    =  valid -- job_type is required when organization_id is present
    # 1      0    =  invalid
    # 0      1    =  invalid
    # 0      0    =  valid
    create(
      constraint("contracts", "job_contracts_must_have_template",
        check:
          "((job_id is not null)::integer + (contract_template_id is not null)::integer) != 1"
      )
    )

    create index(:contracts, [:organization_id])

    create unique_index(:contracts, [:job_id])

    create unique_index(:contracts, [:name, :organization_id],
             where: "contract_template_id is null"
           )

    name = "Picsello Default Contract"

    content =
      "<ol><li><strong>Retainer and Payment.</strong> The Client shall make a retainer to retain the Photographer to perform the services specified herein. At such time as this order is completed, the retainer shall be applied to reduce the total cost and Client shall pay the balance due.</li><li><strong>Cancellation.</strong> If the Client shall cancel this Agreement 14 or more calendar days before the session date, any retainer paid to the Photographer shall be refunded in full. If Client shall cancel within 14 days of the session date and if the Photographer does not obtain another assignment for that time, liquidated damages shall be charged in a reasonable amount not to exceed the retainer.</li><li><strong>Photographic Materials.</strong> All photographic materials, including but not limited to digital files, shall be the exclusive property of the Photographer. The Photographer will make the images available on a photo viewing web site and provide the Client a digital download of the high-res digital files. Client can also choose to print on their own and also use the photographer''s professional lab for professional quality prints.</li><li><strong>Copyright and Reproductions.</strong> The Photographer shall own the copyright in all images created and shall have the exclusive right to make reproductions. The Photographer shall only make reproductions for the Client or for the Photographer''s portfolio, samples, self-promotions, entry in photographic contests or art exhibitions, editorial use, or for display within or on the outside of the Photographer''s studio. If the Photographer desires to make other uses, the Photographer shall not do so without first obtaining the written permission of the Client.</li><li><strong>Client''s Usage.</strong> The Client is obtaining prints for personal use only, and shall not sell said prints or authorize any reproductions thereof by parties other than the Photographer.</li><li><strong>Failure to Perform.</strong> If the Photographer cannot perform this Agreement due to a fire or other casualty, strike, act of God, or other cause beyond the control of the parties, or due to the Photographer''s illness, then the Photographer shall return the retainer to the Client but shall have no further liability with respect to the Agreement. This limitation on liability shall also apply in the event that photographic materials are damaged in processing, lost through camera or computer malfunction, lost in the mail, or otherwise lost or damaged without fault on the part of the Photographer. In the event the Photographer fails to perform for any other reason, the Photographer shall not be liable for any amount in excess of the retail value of the Client''s order.</li><li><strong>Photographer''s Standard Price List.</strong> The charges in this Agreement are based on the Photographer''s Standard Price List. This price list is adjusted periodically and future orders shall be charged at the prices in effect at the time when the order is placed.</li><li><strong>Miscellany.</strong> This Agreement incorporates the entire understanding of the parties. Any modifications of this Agreement must be in writing and signed by both parties. Any waiver of a breach or default hereunder shall not be deemed a waiver of a subsequent breach or default of either the same provision or any other provision of this Agreement. This Agreement shall be governed by the laws of the State of {{state}}.</li><li><strong>RELEASE</strong> I hereby acknowledge that all precautions will be made for a safe shoot and hereby release the Photographer from any liability from any injury incurred during the shoot.</li><li><strong>WARRANTY OF LEGAL CAPACITY</strong> I represent and warrant that I am at least 18 years of age and have the full legal capacity to execute this Agreement.</li><li><strong>PHOTOGRAPHER INFORMATION</strong> {{organization_name}}</li>{{#turnaround_weeks}}<li><strong>DELIVERY OF FINISHED PRODUCT</strong> The client will be presented with the purchased images from the session within {{turnaround_weeks}} of their session date. Though many more images will be recorded, any image that does not meet quality standards will not be shown. The Photographer will choose to show only the best images for purchase consideration. The client''s images will be presented via an online gallery delivered to the client''s email address.</li>{{/turnaround_weeks}}</ol>"

    execute(
      """
        insert into contracts (name, content, inserted_at, updated_at) values ('#{name}', '#{content}', now(), now());
      """,
      ""
    )

    execute(
      """
        insert into contracts (name, content, job_id, contract_template_id, inserted_at, updated_at)
        select contracts.name, contracts.content, booking_proposals.job_id, contracts.id, now(), now()
        from booking_proposals, contracts;
      """,
      ""
    )
  end
end
