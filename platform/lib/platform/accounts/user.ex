defmodule Platform.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material
  alias Platform.Invites

  schema "users" do
    # General metadata
    field :email, :string
    field :username, :string
    field :roles, {:array, Ecto.Enum}, values: [:trusted, :admin, :coordinator]
    field :restrictions, {:array, Ecto.Enum}, values: [:suspended, :muted]
    field :bio, :string, default: ""
    field :profile_photo_file, :string, default: ""
    field :flair, :string, default: ""
    field :admin_notes, :string, default: ""

    # Multi-factor authentication
    field :has_mfa, :boolean, default: false
    field :otp_secret, :binary, redact: true
    field :current_otp_code, :string, virtual: true, redact: true

    # Platform settings and preferences
    field :active_incidents_tab, :string, default: "map"
    belongs_to :active_project_membership, Platform.Projects.ProjectMembership, type: :binary_id

    # Authentication, identity, and compliance
    field :invite_code, :string, virtual: true
    field :terms_agree, :boolean, virtual: true
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    many_to_many :subscribed_media, Material.Media, join_through: "media_subscriptions"
    belongs_to :invite, Platform.Invites.Invite

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
    |> cast(attrs, [:email, :password, :username, :invite_code, :terms_agree])
    |> validate_email()
    |> validate_username()
    |> validate_terms_agreement()
    |> validate_password(opts)
  end

  def validate_invite_code(changeset) do
    changeset
    |> validate_required([:invite_code])
    |> validate_change(:invite_code, fn _, code ->
      case Invites.get_invite_by_code(code) do
        nil ->
          [invite_code: "not a valid invite code"]

        code ->
          case code.active do
            true -> []
            false -> [invite_code: "this invite code has expired"]
          end
      end
    end)
    # Actually insert the invite code into the changeset so that it persists
    |> put_change(
      :invite_id,
      case Map.get(changeset.changes, :invite_code) do
        nil ->
          nil

        code ->
          case Invites.get_invite_by_code(code) do
            nil -> nil
            invite -> invite.id
          end
      end
    )
  end

  defp validate_terms_agreement(changeset) do
    changeset
    |> validate_exclusion(:terms_agree, [false], message: "You must agree to the Atlos terms.")
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Platform.Repo)
    |> unique_constraint(:email)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[A-Za-z0-9]+$/,
      message: "must be alphaneumeric with no spaces"
    )
    |> validate_length(:username, min: 3, max: 32)
    |> unsafe_validate_unique(:username, Platform.Repo)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
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
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp verify_otp_code(secret, code) do
    time = System.os_time(:second)

    NimbleTOTP.valid?(secret, code, time: time) or
      NimbleTOTP.valid?(secret, code, time: time - 30)
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for enabling MFA.
  """
  def enable_mfa_changeset(user, attrs) do
    changeset =
      user
      |> cast(attrs, [:otp_secret, :current_otp_code])
      |> put_change(:has_mfa, true)
      |> validate_required([:has_mfa, :otp_secret, :current_otp_code])

    secret = get_field(changeset, :otp_secret)

    changeset
    |> validate_change(:current_otp_code, fn _, code ->
      if verify_otp_code(secret, code) do
        []
      else
        [current_otp_code: "This code is not valid."]
      end
    end)
  end

  @doc """
  A user changeset for disabling MFA.
  """
  def disable_mfa_changeset(user, attrs) do
    user
    |> cast(attrs, [:current_otp_code, :password])
    |> put_change(:has_mfa, false)
    |> put_change(:otp_secret, nil)
    |> validate_required([:has_mfa, :current_otp_code, :password])
    |> validate_change(:password, fn _, password ->
      if valid_password?(user, password) do
        []
      else
        [password: "This password is not correct."]
      end
    end)
    |> validate_change(:current_otp_code, fn _, code ->
      if verify_otp_code(user.otp_secret, code) do
        []
      else
        [current_otp_code: "This code is not valid."]
      end
    end)
  end

  @doc """
  A user changeset for disabling MFA.
  """
  def confirm_mfa_changeset(user, attrs) do
    user
    |> cast(attrs, [:current_otp_code])
    |> validate_change(:current_otp_code, fn _, code ->
      if verify_otp_code(user.otp_secret, code) do
        []
      else
        [current_otp_code: "This code is not valid."]
      end
    end)
  end

  @doc """
  A user changeset for changing user-modifiable profile attributes,
  like the profile photo and bio.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:bio, :profile_photo_file])
    |> validate_length(:bio, max: 240, message: "Bios may not exceed 240 characters.")
  end

  @doc """
  A user changeset for modifying admin/safety attributes, such as
  roles and restrictions.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:roles, :restrictions, :bio, :flair, :admin_notes])
    |> validate_length(:bio, max: 240, message: "Bios may not exceed 240 characters.")
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
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def preferences_changeset(user, attrs) do
    user
    |> cast(attrs, [:active_incidents_tab, :active_project_membership_id])
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Platform.Accounts.User{hashed_password: hashed_password}, password)
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
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
