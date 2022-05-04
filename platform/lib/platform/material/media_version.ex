defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Accounts
  alias __MODULE__

  schema "media_versions" do
    field :file_location, :string
    field :file_size, :integer
    field :mime_type, :string
    field :client_name, :string
    field :duration_seconds, :integer

    field :upload_type, Ecto.Enum, values: [:user_provided, :direct], default: :user_provided
    field :status, Ecto.Enum, values: [:pending, :complete, :error], default: :complete
    field :source_url, :string

    field :hidden, :boolean, default: false

    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [
      :file_location,
      :file_size,
      :upload_type,
      :status,
      :duration_seconds,
      :source_url,
      :mime_type,
      :client_name,
      :media_id,
      :hidden
    ])
    |> validate_required([
      :status,
      :upload_type,
      :media_id
    ])
    |> validate_required([:source_url],
      message: "Please provide a source link to demonstrate the media's authenticity."
    )
  end

  @doc """
  Can the given user view the media version?
  """
  def can_user_view(%MediaVersion{} = version, %Accounts.User{} = user) do
    case version.hidden do
      true -> Accounts.is_privileged(user)
      false -> true
    end
  end
end
