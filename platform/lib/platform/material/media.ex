defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils
  alias Platform.Material.Attribute
  alias Platform.Accounts.User
  alias __MODULE__

  schema "media" do
    # Core uneditable data
    field :slug, :string, autogenerate: {Utils, :generate_media_slug, []}

    # Core editable data
    field :description, :string

    # "Normal" Attributes
    field :attr_time_of_day, :string
    field :attr_geolocation, Geo.PostGIS.Geometry
    field :attr_environment, :string
    field :attr_weather, {:array, :string}
    field :attr_recorded_by, :string
    field :attr_more_info, :string
    field :attr_civilian_impact, {:array, :string}
    field :attr_event, {:array, :string}
    field :attr_casualty, {:array, :string}
    field :attr_military_infrastructure, {:array, :string}
    field :attr_weapon, {:array, :string}
    field :attr_time_recorded, :time
    field :attr_date_recorded, :date

    # Safety & Access Control Attributes
    field :attr_restrictions, {:array, :string}
    field :attr_sensitive, {:array, :string}

    # Virtual attributes for updates + multi-part attributes
    field :explanation, :string, virtual: true
    field :latitude, :float, virtual: true
    field :longitude, :float, virtual: true

    # Metadata
    timestamps()

    # Associations
    has_many :versions, Platform.Material.MediaVersion
    has_many :updates, Platform.Updates.Update
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:description, :attr_sensitive])
    |> validate_required([:description])

    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive))
    |> Attribute.validate_attribute(Attribute.get_attribute(:description))
  end

  def attribute_ratio(%Media{} = media) do
    length(Attribute.set_for_media(media)) / length(Attribute.attribute_names())
  end

  def is_sensitive(%Media{} = media) do
    case media.attr_sensitive do
      ["Not Sensitive"] -> false
      _ -> true
    end
  end

  @doc """
  Can the user view the media? Currently this is true for all media *except* media for which the "Hidden" restriction is present and the user is not an admin.
  """
  def can_user_view(%Media{} = media, %User{} = user) do
    case media.attr_restrictions do
      nil ->
        true

      values ->
        # Restrictions are present.
        if Enum.member?(values, "Hidden") do
          Enum.member?(user.roles || [], :admin)
        else
          true
        end
    end
  end

  @doc """
  Can the given user edit the media? This includes uploading new media versions as well as editing attributes.
  """
  def can_user_edit(%Media{} = media, %User{} = user) do
    case media.attr_restrictions do
      nil ->
        true

      values ->
        # Restrictions are present.
        if Enum.member?(values, "Hidden") || Enum.member?(values, "No Edits") do
          Enum.member?(user.roles || [], :admin)
        else
          true
        end
    end
  end

  def has_restrictions(%Media{} = media) do
    length(media.attr_restrictions || []) > 0
  end
end
