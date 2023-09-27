defmodule Picsello.NylasDetails do
  @moduledoc false
  alias Picsello.{Repo, Workers.CalendarEvent, NylasDetail}
  alias Ecto.{Changeset, Multi}

  @spec set_nylas_token!(NylasDetail.t(), map()) :: NylasDetail.t()
  def set_nylas_token!(%NylasDetail{} = nylas_detail, attrs) do
    nylas_detail
    |> NylasDetail.set_token_changeset(attrs)
    |> Repo.update!()
  end

  @spec clear_nylas_token!(NylasDetail.t()) :: NylasDetail.t()
  def clear_nylas_token!(%NylasDetail{} = nylas_detail) do
    nylas_detail
    |> NylasDetail.clear_token_changeset()
    |> Repo.update!()
  end

  @spec set_nylas_calendars!(NylasDetail.t(), map()) :: NylasDetail.t()
  def set_nylas_calendars!(%NylasDetail{user_id: user_id} = nylas_detail, calendars) do
    changeset = NylasDetail.set_calendars_changeset(nylas_detail, calendars)

    case changeset |> Changeset.apply_changes() do
      %{event_status: :initial, external_calendar_rw_id: rw_id} when not is_nil(rw_id) ->
        changeset
        |> update_nylas_detail!(user_id, "initial")

      %{event_status: :in_progress, external_calendar_rw_id: rw_id} when not is_nil(rw_id) ->
        changeset
        |> update_nylas_detail!(user_id, "move")

      _ ->
        changeset
        |> Repo.update!()
    end
  end

  @spec reset_event_status!(NylasDetail.t()) :: NylasDetail.t()
  def reset_event_status!(%NylasDetail{} = nylas_detail) do
    nylas_detail
    |> Changeset.change()
    |> NylasDetail.event_status_change()
    |> Repo.update!()
  end

  defp update_nylas_detail!(changeset, user_id, type) do
    Multi.new()
    |> Multi.update(:nylas_detail, changeset)
    |> Oban.insert(
      :move_events,
      CalendarEvent.new(%{type: type, user_id: user_id})
    )
    |> Repo.transaction()
    |> then(fn {:ok, %{nylas_detail: nylas_detail}} -> nylas_detail end)
  end
end
