defmodule Picsello.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Onboardings.Onboarding

  @email_regex ~r/^[^\s]+@[^\s]+\.[^\s]+$/
  @derive {Inspect, except: [:password]}

  schema "users" do
    field :confirmed_at, :naive_datetime
    field :email, :string
    field :hashed_password, :string
    field :name, :string
    field :password, :string, virtual: true
    field :time_zone, :string
    field :sign_up_auth_provider, Ecto.Enum, values: [:google, :password], default: :password
    embeds_one(:onboarding, Onboarding, on_replace: :update)

    belongs_to(:organization, Picsello.Organization)

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(put_new_attr(attrs, :organization, %{}), [
      :email,
      :name,
      :password,
      :time_zone
    ])
    |> validate_required([:name])
    |> validate_email()
    |> validate_password(opts)
    |> then(
      &cast_assoc(&1, :organization,
        with: {Picsello.Organization, :registration_changeset, [get_field(&1, :name)]}
      )
    )
  end

  def new_session_changeset(user \\ %__MODULE__{}, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email_format()
    |> validate_required([:password])
  end

  def reset_password_changeset(user \\ %__MODULE__{}, attrs \\ %{}) do
    user
    |> cast(attrs, [:email])
    |> validate_email_format()
  end

  def validate_email_format(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, email_regex(), message: "is invalid")
    |> validate_length(:email, max: 160)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_email_format()
    |> unsafe_validate_unique(:email, Picsello.Repo)
    |> unique_constraint(:email)
  end

  def email_regex(), do: @email_regex

  def validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 80)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> validate_previous_sign_up_auth_provider(
      message: "must sign up with password to change email"
    )
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_previous_sign_up_auth_provider(
      message: "must sign up with password to change password"
    )
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def validate_previous_sign_up_auth_provider(changeset, opts) do
    message = opts |> Keyword.get(:message, "is invalid")

    case changeset |> get_field(:sign_up_auth_provider) do
      :password ->
        changeset

      _ ->
        add_error(
          changeset,
          :sign_up_auth_provider,
          message
        )
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def complete_onboarding_changeset(user) do
    user
    |> change()
    |> put_embed(:onboarding, %{completed_at: DateTime.utc_now()})
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Picsello.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password, field \\ :current_password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, field, "is not valid")
    end
  end

  def initials(%__MODULE__{name: name}) do
    case name |> String.split() do
      [first_name | [_ | _] = rest] ->
        [first_name, rest |> List.last()]
        |> Enum.map(&String.first/1)
        |> Enum.join()

      [first_name] ->
        first_name |> String.slice(0..1)
    end
    |> String.upcase()
  end

  def first_name(%__MODULE__{name: name}), do: name |> String.split() |> hd

  @doc """
  true if user has skipped or completed all onboarding steps.
  """
  def onboarded?(%__MODULE__{onboarding: nil}), do: false
  def onboarded?(%__MODULE__{onboarding: onboarding}), do: Onboarding.completed?(onboarding)

  def confirmed?(%__MODULE__{confirmed_at: nil, sign_up_auth_provider: :password}), do: false
  def confirmed?(%__MODULE__{}), do: true

  def put_new_attr(map, atom, value) when is_atom(atom) do
    Map.put_new(map, match_key_type(map).(atom), value)
  end

  def update_attr_in(map, path, f) do
    update_in(map, Enum.map(path, match_key_type(map)), f)
  end

  defp match_key_type(%{} = map) do
    case Map.keys(map) do
      [first_key | _] when is_atom(first_key) -> & &1
      _ -> &Atom.to_string/1
    end
  end
end
