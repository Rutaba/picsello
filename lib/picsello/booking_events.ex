defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.{Repo, BookingEvent}
  import Ecto.Query

  def upsert_booking_event(changeset) do
    changeset
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:id],
      returning: true
    )
  end

  def get_booking_events(organization_id) do
    from(event in BookingEvent,
      join: package in assoc(event, :package_template),
      where: package.organization_id == ^organization_id,
      preload: [package_template: package]
    )
    |> Repo.all()
  end
end
