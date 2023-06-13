defmodule Picsello.ShootTest do
  use Picsello.DataCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias Picsello.Accounts
  alias Picsello.Shoot
  alias Picsello.Shoot
  alias :meck, as: Meck
  alias Picsello.Accounts.User
  import Ecto.Changeset
  @token "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
  @calendar_id "abcdefg"
  @fields [
    :starts_at,
    :duration_minutes,
    :name,
    :location,
    :notes,
    :job_id,
    :address
  ]

  setup do
    user = :user |> insert() |> Accounts.set_user_nylas_code(@token)

    Picsello.Accounts.User.set_nylas_calendars(user, %{
      external_calendar_rw_id: @calendar_id,
      external_calendar_read_list: []
    })

    job = :lead |> insert(user: user) |> promote_to_job()
    gallery = insert(:gallery, job: job)

    %{
      gallery: gallery,
      job: job,
      user: user,
      attrs: %{
        starts_at: ~U[2023-11-15 10:00:00Z],
        duration_minutes: 60,
        name: "Test Event",
        location: :studio,
        notes: "Lorem ipsum dolor sit amet",
        job_id: job.id,
        address: "123 Some Street"
      }
    }
  end

  def create_changeset(attrs) do
    cast(%Shoot{}, attrs, @fields)
  end

  @tag :skip
  describe "push_changes_to_nylas/1" do
    test "NoOp", %{attrs: attrs} do
      changeset = create_changeset(attrs)
      assert changeset == Picsello.Shoot.push_changes_to_nylas(changeset)
    end

    test "Create Changeset calls push_changes_to_nylas/1", %{attrs: attrs} do
      Meck.new(Picsello.Shoot, [:passthrough])

      Meck.expect(Picsello.Shoot, :push_changes_to_nylas, fn c ->
        c
      end)

      Shoot.create_changeset(attrs) |> Repo.insert!()
      assert Meck.validate(Picsello.Shoot)
      assert Meck.called(Picsello.Shoot, :push_changes_to_nylas, 1)
    end

    @tag :skip
    test "Update Changeset calls push_changes_to_nylas/1", %{attrs: _attrs, gallery: gallery} do
      [shoot, _] = gallery.job.shoots
      Meck.new(Picsello.Shoot, [:passthrough])

      Meck.expect(Picsello.Shoot, :push_changes_to_nylas, fn c -> c end)

      Shoot.update_changeset(shoot, %{
        starts_at: ~U[2023-11-01 10:00:00Z],
        duration_minutes: 90,
        name: "FAKE Event",
        location: :studio
      })
      |> Repo.update!()

      assert Meck.called(Picsello.Shoot, :push_changes_to_nylas, 1)

      assert Meck.validate(Picsello.Shoot)
    end

    @tag :skip
    test "push to new event to nylas", %{attrs: attrs} do
      attrs
      |> create_changeset()
      |> Shoot.push_changes_to_nylas()
    end

    @tag :skip
    test "Push Existing event to Nylas on update", %{gallery: gallery} do
      [shoot, _] = gallery.job.shoots

      shoot
      |> cast(
        %{
          starts_at: ~U[2023-11-01 10:00:00Z],
          duration_minutes: 90,
          name: "FAKE Event",
          location: :studio
        },
        @fields
      )
      |> Shoot.push_changes_to_nylas()
    end

    test "Get token from shoot", %{gallery: gallery} do
      [shoot, _] = gallery.job.shoots

      assert %User{nylas_oauth_token: @token, external_calendar_rw_id: @calendar_id} =
               Shoot.get_token_from_shoot(shoot)
    end

    @tag :skip
    test "Do not push to nylas with out a valid user" do
    end

    @tag :skip
    test "Delete Event from Shoot table " do
      throw(:not_yet_implemented)
    end

    @tag :skip
    test "Do not show our events on pull " do
      throw(:not_yet_implemented)
    end

    @tag :skip
    test "Do not double push events" do
      throw(:not_yet_implemented)
    end
  end
end
