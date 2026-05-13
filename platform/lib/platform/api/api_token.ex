defmodule Platform.API.APIToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "api_tokens" do
    field :is_active, :boolean, default: true

    field :name, :string
    field :description, :string

    # This is the actual token value
    field :value, :string

    field :last_used, :date
    field :is_legacy, :boolean, default: false

    field :permissions, {:array, Ecto.Enum}, default: [:read], values: [:read, :comment, :edit]

    belongs_to :project, Platform.Projects.Project, type: :binary_id
    belongs_to :creator, Platform.Accounts.User, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [
      :name,
      :description,
      :project_id,
      :permissions,
      :creator_id,
      :is_legacy,
      :is_active
    ])
    |> validate_required([:name, :creator_id, :permissions])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, min: 3, max: 1000)
    # Ensure that the token only contains valid permissions
    |> validate_change(:permissions, fn :permissions, permissions ->
      if Enum.all?(permissions, &Enum.member?([:read, :comment, :edit], &1)) do
        []
      else
        [permissions: "Invalid permissions specified"]
      end
    end)
    # Ensure that the token has at least `:read` permissions
    |> validate_change(:permissions, fn :permissions, permissions ->
      if Enum.member?(permissions, :read) do
        []
      else
        [permissions: "API tokens must have read permissions"]
      end
    end)
    # If the token previously was inactive, ensure that it remains inactive
    |> validate_change(:is_active, fn :is_active, is_active ->
      if is_active and not api_token.is_active do
        [is_active: "Cannot reactivate an inactive token"]
      else
        []
      end
    end)
    |> validate_project(api_token)
    |> validate_is_legacy(api_token)
    |> assoc_constraint(:project)
    |> assoc_constraint(:creator)
    |> put_change(:value, Platform.Utils.generate_secure_code())
  end

  defp validate_project(changeset, api_token) do
    case get_change(changeset, :project_id, :no_change) do
      :no_change ->
        changeset

      _value ->
        if api_token.id,
          do: add_error(changeset, :project_id, "Cannot change a token's project"),
          else: changeset
    end
  end

  defp validate_is_legacy(changeset, api_token) do
    case get_change(changeset, :is_legacy, :no_change) do
      :no_change ->
        changeset

      _value ->
        if api_token.id,
          do: add_error(changeset, :is_legacy, "Cannot change a token's legacy status"),
          else: changeset
    end
  end

  @doc """
  An admin-managed token is one that surfaces in Adminland: legacy v1 tokens
  and instance-wide v2 tokens (no project). Project-scoped tokens are managed
  by their project's owners and excluded.
  """
  def admin_managed?(%__MODULE__{is_legacy: true}), do: true
  def admin_managed?(%__MODULE__{project_id: nil}), do: true
  def admin_managed?(%__MODULE__{}), do: false
end
