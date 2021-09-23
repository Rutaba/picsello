defmodule Picsello.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Onboarding do
    @moduledoc false

    use Ecto.Schema

    @colors ~w(#5C6578 #3376FF #3AE7C7 #E466F8 #1AD0DC #FFD80D #F8AC66 #9566F8)

    @primary_key false
    embedded_schema do
      field(:website, :string)
      field(:color, :string, default: @colors |> hd)
      field(:no_website, :boolean, default: false)
      field(:phone, :string)
      field(:schedule, Ecto.Enum, values: [:full_time, :part_time])
      field(:completed_at, :utc_datetime)
    end

    def colors(), do: @colors

    def changeset(%__MODULE__{} = onboarding, attrs) do
      onboarding
      |> cast(attrs, [:no_website, :website, :phone, :schedule, :color])
      |> then(
        &if get_field(&1, :no_website),
          do: put_change(&1, :website, nil),
          else: &1
      )
      |> validate_change(:website, &for(e <- url_validation_errors(&2), do: {&1, e}))
      |> validate_change(:phone, &valid_phone/2)
    end

    def completed?(%__MODULE__{completed_at: nil}), do: false
    def completed?(%__MODULE__{}), do: true

    def url_validation_errors(url) do
      case URI.parse(url) do
        %{scheme: nil} ->
          ("https://" <> url) |> url_validation_errors()

        %{scheme: scheme, host: "" <> host} when scheme in ["http", "https"] ->
          label = "[a-z0-9\\-]{1,63}+"

          if Regex.compile!("^(?:(?:#{label})\\.)+(?:#{label})$")
             |> Regex.match?(host),
             do: [],
             else: ["invalid host #{host}"]

        %{scheme: scheme} ->
          ["invalid scheme #{scheme}"]
      end
    end

    defdelegate valid_phone(field, value), to: Picsello.Client
  end

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
    |> cast(attrs, [:email, :name, :password, :time_zone])
    |> validate_required([:name])
    |> validate_email()
    |> validate_password(opts)
    |> then(
      &put_assoc(&1, :organization, %Picsello.Organization{
        name: "#{get_field(&1, :name)} Photography"
      })
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

  def onboarding_changeset(user \\ %__MODULE__{}, attrs \\ %{}) do
    user
    |> cast(attrs, [])
    |> cast_embed(:onboarding, required: true)
    |> cast_assoc(:organization, with: &Picsello.Organization.registration_changeset/2)
  end

  def validate_email_format(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_email_format()
    |> unsafe_validate_unique(:email, Picsello.Repo)
    |> unique_constraint(:email)
  end

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

  @doc """
  true if user has skipped or completed all onboarding steps.
  """
  def onboarded?(%__MODULE__{onboarding: nil}), do: false
  def onboarded?(%__MODULE__{onboarding: onboarding}), do: Onboarding.completed?(onboarding)
end
