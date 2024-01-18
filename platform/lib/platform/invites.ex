defmodule Platform.Invites do
  @moduledoc """
  The Invites context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo
  alias Platform.Accounts
  alias Platform.Projects
  alias Platform.Notifications
  alias Platform.Utils

  alias Platform.Invites.Invite
  alias Platform.Invites.InviteUse

  @doc """
  Returns the list of invites.

  ## Examples

      iex> list_invites()
      [%Invite{}, ...]

  """
  def list_invites do
    Repo.all(preload_invites(Invite))
  end

  @doc """
  Gets a single invite.

  Raises `Ecto.NoResultsError` if the Invite does not exist.

  ## Examples

      iex> get_invite!(123)
      %Invite{}

      iex> get_invite!(456)
      ** (Ecto.NoResultsError)

  """
  def get_invite!(id), do: Repo.get!(preload_invites(Invite), id)

  @doc """
  Gets an invite by its code.

  Options:
    * `:must_be_active` - If true, only active invites will be returned. Defaults to true.
  """
  def get_invite_by_code(code, opts \\ []) do
    must_be_active = Keyword.get(opts, :must_be_active, true)

    # When in test environment, "TESTING" is a valid invite code
    with "true" <- System.get_env("DEVELOPMENT_MODE", "false"), "TESTING" <- code do
      Repo.get_by(Invite, code: Accounts.get_valid_invite_code())
    else
      _ ->
        invite = Repo.get_by(Invite |> preload_invites(), code: code)

        if must_be_active and
             not is_invite_active(invite) do
          nil
        else
          invite
        end
    end
  end

  def is_invite_active(nil), do: false

  def is_invite_active(%Invite{} = invite) do
    invite.active and
      (is_nil(invite.expires) or
         NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires) == :lt)
  end

  @doc """
  Gets an invite by its user.
  """
  def get_invites_by_user(nil),
    do: from(i in preload_invites(Invite), where: is_nil(i.owner_id)) |> Repo.all()

  def get_invites_by_user(user),
    do: from(i in preload_invites(Invite), where: i.owner_id == ^user.id) |> Repo.all()

  @doc """
  Gets an invite by its project.
  """
  def get_invites_by_project(project) when is_nil(project),
    do: from(i in preload_invites(Invite), where: is_nil(i.project_id)) |> Repo.all()

  def get_invites_by_project(project),
    do: from(i in preload_invites(Invite), where: i.project_id == ^project.id) |> Repo.all()

  defp preload_invites(query) do
    query
    |> preload([:owner, :project, uses: [:user]])
  end

  @doc """
  Creates a invite.

  ## Examples

      iex> create_invite(%{field: value})
      {:ok, %Invite{}}

      iex> create_invite(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_invite(attrs \\ %{}) do
    %Invite{}
    |> Invite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a invite.

  ## Examples

      iex> update_invite(invite, %{field: new_value})
      {:ok, %Invite{}}

      iex> update_invite(invite, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_invite(%Invite{} = invite, attrs) do
    invite
    |> Invite.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a invite.

  ## Examples

      iex> delete_invite(invite)
      {:ok, %Invite{}}

      iex> delete_invite(invite)
      {:error, %Ecto.Changeset{}}

  """
  def delete_invite(%Invite{} = invite) do
    Repo.delete(invite)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking invite changes.

  ## Examples

      iex> change_invite(invite)
      %Ecto.Changeset{data: %Invite{}}

  """
  def change_invite(%Invite{} = invite, attrs \\ %{}) do
    Invite.changeset(invite, attrs)
  end

  @doc """
  Creates a invite use.

  ## Examples

      iex> create_invite_use(%{field: value})
      {:ok, %InviteUse{}}

      iex> create_invite_use(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_invite_use(attrs \\ %{}) do
    %InviteUse{}
    |> InviteUse.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get the invite uses by a user.

  ## Examples

      iex> get_invite_uses_by_user(user)
      [%InviteUse{}, ...]
  """
  def get_invite_uses_by_user(user) do
    from(i in InviteUse, where: i.user_id == ^user.id) |> Repo.all()
  end

  @doc """
  Applies the invite code to the user. This will mark the invite as used and
  grant the user access to the project, if specified.

  It's recommended to run this in a transaction.
  """
  def apply_invite_code(%Accounts.User{} = user, code) do
    invite = get_invite_by_code(code)

    if is_nil(invite) or not is_invite_active(invite) do
      {:error, "Invalid invite code"}
    else
      # If the code is single use, mark it as used
      if invite.single_use do
        {:ok, _} = update_invite(invite, %{active: false})
      end

      # Create an invite use
      {:ok, _} =
        create_invite_use(%{
          user_id: user.id,
          invite_id: invite.id
        })

      # Add the user to the project at the specified access level, if specified
      if not is_nil(invite.project_id) do
        project = Projects.get_project!(invite.project_id)

        case Projects.create_project_membership(%{
               project_id: invite.project_id,
               username: user.username,
               role: invite.project_access_level
             }) do
          {:ok, _} ->
            {:ok, invite}

          {:error, _} ->
            {:error, "Failed to add user to project"}
        end

        if not is_nil(invite.owner) do
          {:ok, _} =
            Notifications.send_message_notification_to_user(
              invite.owner,
              "[@#{user.username}](/profile/#{user.username}) accepted your invite to join [#{Utils.escape_markdown_string(project.name)}](/projects/#{project.id}) as #{if Enum.member?([:editor, :owner], invite.project_access_level), do: "an", else: "a"} #{to_string(invite.project_access_level)}."
            )
        end

        {:ok, invite}
      else
        if not is_nil(invite.owner) do
          {:ok, _} =
            Notifications.send_message_notification_to_user(
              invite.owner,
              "[@#{user.username}](/profile/#{user.username}) accepted your invite."
            )
        end

        {:ok, invite}
      end
    end
  end
end
