defmodule Platform.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo
  alias Platform.Utils

  alias Platform.Accounts.{User, UserToken, UserNotifier}
  alias Platform.Invites

  use Memoize

  def get_valid_invite_code() do
    # Find invites created by the system (nil user)
    invites = Invites.get_invites_by_user(nil)

    case length(invites) do
      0 ->
        # No root invites; create a system invite (i.e., root `owner_id`)
        {:ok, invite} = Invites.create_invite()
        invite.code

      _ ->
        hd(invites).code
    end
  end

  def is_auto_account(%User{username: "Atlos"}), do: true
  def is_auto_account(_), do: false

  def get_auto_account() do
    case get_user_by_username("atlos") do
      nil ->
        # No admin! Create the user
        {:ok, user} =
          register_user(
            %{
              username: "Atlos",
              email: "admin@atlos.org",
              invite_code: get_valid_invite_code(),
              password: Utils.generate_secure_code()
            },
            allow_special_users: true
          )

        {:ok, user} = update_user_admin(user, %{roles: [:trusted], flair: "Bot"})

        user

      val ->
        val
    end
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User |> preload_user(), email: email)
  end

  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User |> preload_user(), username: username)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User |> preload_user(), email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User |> preload_user(), id)

  defmemo get_user(id), expires_in: 5000 do
    Repo.get(User |> preload_user(), id)
  end

  defmemo get_users_by_ids(ids), expires_in: 5000 do
    Repo.all(User |> preload_user() |> where([u], u.id in ^ids))
  end

  @doc """
  Gets all users, and preloads their invite code (and the owner of that invite code).
  """
  def get_all_users(), do: Repo.all(User |> preload_user())

  ## User registration

  @doc """
  Registers a user. Note that users are not allowed to register with special
  usernames (specifically, `Atlos`, unless the `allow_special_users` option is
  set to true).

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs, opts \\ []) do
    changeset =
      %User{}
      |> User.registration_changeset(attrs, opts)
      # We only validate the invite code when they actually submit, to prevent enumeration (at this point, they must have completed the captcha)
      |> User.validate_invite_code()

    Repo.transaction(fn ->
      case changeset
           |> Repo.insert() do
        {:ok, user} ->
          # Apply the invite code to the user, if applicable
          invite_code = Ecto.Changeset.get_field(changeset, :invite_code)

          if not is_nil(invite_code) do
            {:ok, _} = Invites.apply_invite_code(user, invite_code)
          end

          {:ok, user}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user's preferences.

  ## Examples

      iex> change_user_preferences(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_preferences(%User{} = user, attrs \\ %{}) do
    User.preferences_changeset(user, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for enabling MFA.
  """
  def change_user_mfa_enabled(user, attrs \\ %{}) do
    User.enable_mfa_changeset(user, attrs)
  end

  @doc """
  Enables MFA for a user.
  """
  def update_user_mfa_enabled(user, attrs \\ %{}) do
    User.enable_mfa_changeset(user, attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for disabling MFA.
  """
  def change_user_mfa_disabled(user, attrs \\ %{}) do
    User.disable_mfa_changeset(user, attrs)
  end

  @doc """
  Disables MFA for a user.
  """
  def update_user_mfa_disabled(user, attrs \\ %{}) do
    User.disable_mfa_changeset(user, attrs)
    |> Repo.update()
  end

  @doc """
  Confirms a user's MFA code.
  """
  def confirm_user_mfa(user, attrs \\ %{}) do
    User.confirm_mfa_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  defp preload_user(queryable) do
    queryable |> preload([:active_project_membership])
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query) |> Repo.preload([:active_project_membership])
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Deletes all session tokens.
  """
  def delete_all_session_tokens() do
    Repo.delete_all(from(Platform.Accounts.UserToken, where: [context: "session"]))
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def active_project_id(user) do
    case user.active_project_membership do
      nil -> nil
      %Platform.Projects.ProjectMembership{project_id: project_id} -> project_id
    end
  end

  def active_incidents_params(user) do
    case user.active_incidents_tab_params_time do
      nil ->
        %{project_id: active_project_id(user)}

      time ->
        # If the time is older than an hour, we don't want to use it
        if NaiveDateTime.diff(NaiveDateTime.utc_now(), time) > 3600 do
          %{project_id: active_project_id(user)}
        else
          user.active_incidents_tab_params || %{}
        end
    end
  end

  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_user_profile(user, attrs) do
    change_user_profile(user, attrs)
    |> Repo.update()
  end

  def update_user_preferences(user, attrs) do
    change_user_preferences(user, attrs)
    |> Repo.update()
  end

  def get_profile_photo_path(%User{} = user) do
    cond do
      String.starts_with?(user.profile_photo_file, "https://") ->
        user.profile_photo_file

      user.username == "Atlos" ->
        "/images/bot_profile.png"

      String.length(user.profile_photo_file) == 0 ->
        "/images/default_profile.jpg"

      true ->
        Platform.Uploads.Avatar.url({user.profile_photo_file, user}, :thumb,
          signed: true,
          expires_in: 60 * 60 * 6
        )
    end
  end

  def change_user_admin(user, attrs \\ %{}) do
    User.admin_changeset(user, attrs)
  end

  def update_user_admin(user, attrs) do
    change_user_admin(user, attrs)
    |> Repo.update()
  end

  def is_admin(%User{} = user) do
    Enum.member?(user.roles || [], :admin)
  end

  def is_trusted(%User{} = user) do
    Enum.member?(user.roles || [], :trusted)
  end

  def is_privileged(%User{} = user) do
    is_admin(user) || is_trusted(user)
  end

  def is_suspended(%User{} = user) do
    Enum.member?(user.restrictions || [], :suspended)
  end

  def is_muted(%User{} = user) do
    Enum.member?(user.restrictions || [], :muted)
  end

  def is_bot(%User{} = user) do
    user.username == "Atlos"
  end
end
