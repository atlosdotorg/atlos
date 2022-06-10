defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Platform.Utils
  alias Platform.Material.Attribute
  alias Platform.Material.MediaSubscription
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias __MODULE__

  schema "media" do
    # Core uneditable data
    field :slug, :string, autogenerate: {Utils, :generate_media_slug, []}

    # "Normal" Attributes
    field :description, :string
    field :attr_time_of_day, :string
    field :attr_geolocation, Geo.PostGIS.Geometry
    field :attr_environment, :string
    field :attr_weather, {:array, :string}
    field :attr_camera_system, :string
    field :attr_more_info, :string
    field :attr_civilian_impact, {:array, :string}
    field :attr_event, {:array, :string}
    field :attr_casualty, {:array, :string}
    field :attr_military_infrastructure, {:array, :string}
    field :attr_weapon, {:array, :string}
    field :attr_time_recorded, :time
    field :attr_date_recorded, :date

    # Metadata Attributes
    field :attr_restrictions, {:array, :string}
    field :attr_sensitive, {:array, :string}
    field :attr_status, :string

    # Virtual attributes for updates + multi-part attributes
    field :explanation, :string, virtual: true
    field :latitude, :float, virtual: true
    field :longitude, :float, virtual: true

    # Metadata
    timestamps()

    # Associations
    has_many :versions, Platform.Material.MediaVersion
    has_many :updates, Platform.Updates.Update
    has_many :subscriptions, MediaSubscription
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:description, :attr_sensitive, :attr_status])
    |> validate_required([:description],
      message: "Incident descriptions can't be blank. Please describe the incident."
    )
    |> validate_length(:description,
      min: 8,
      max: 240,
      message: "Incident descriptions should be between 8 and 240 characters."
    )
    |> validate_required([:attr_sensitive],
      message:
        "Sensitivity must be set. If this incident doesn't include sensitive media, choose 'Not Sensitive.'"
    )

    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive))
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
    case Enum.member?(user.restrictions || [], :muted) do
      true ->
        false

      false ->
        case media.attr_restrictions do
          nil ->
            true

          values ->
            # Restrictions are present.
            if Enum.member?(values, "Hidden") || Enum.member?(values, "Frozen") do
              Accounts.is_privileged(user)
            else
              true
            end
        end
    end
  end

  def has_restrictions(%Media{} = media) do
    length(media.attr_restrictions || []) > 0
  end

  def is_graphic(%Media{} = media) do
    Enum.member?(media.attr_sensitive || [], "Graphic Violence")
  end

  def text_search(search_terms, queryable \\ Media) do
    Utils.text_search(search_terms, queryable)
  end
end
