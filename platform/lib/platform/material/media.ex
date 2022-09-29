defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils
  alias Platform.Material.Attribute
  alias Platform.Material.MediaSubscription
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias __MODULE__

  schema "media" do
    # Core uneditable data
    field :slug, :string, autogenerate: {Utils, :generate_media_slug, []}

    # Core Attributes
    field :attr_description, :string
    field :attr_geolocation, Geo.PostGIS.Geometry
    field :attr_geolocation_resolution, :string
    field :attr_more_info, :string
    field :attr_date, :date
    field :attr_type, {:array, :string}
    field :attr_impact, {:array, :string}
    field :attr_equipment, {:array, :string}

    # Deprecated attributes (that still live in the database)
    # field :attr_time_of_day, :string
    # field :attr_environment, :string
    # field :attr_weather, {:array, :string}
    # field :attr_camera_system, {:array, :string}
    # field :attr_civilian_impact, {:array, :string}
    # field :attr_event, {:array, :string}
    # field :attr_casualty, {:array, :string}
    # field :attr_military_infrastructure, {:array, :string}
    # field :attr_weapon, {:array, :string}
    # field :attr_time_recorded, :time

    # Metadata Attributes
    field :attr_restrictions, {:array, :string}
    field :attr_sensitive, {:array, :string}
    field :attr_status, :string
    field :attr_tags, {:array, :string}

    # Virtual attributes for updates + multi-part attributes
    field :explanation, :string, virtual: true
    field :location, :string, virtual: true

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
    |> cast(attrs, [:attr_description, :attr_sensitive, :attr_status, :attr_type])
    |> validate_required([:attr_description],
      message: "Please add a short description."
    )
    |> validate_length(:attr_description,
      min: 8,
      max: 240,
      message: "Descriptions should be 8-240 characters."
    )
    |> validate_required([:attr_sensitive],
      message:
        "Sensitivity must be set. If this incident doesn't include sensitive media, choose 'Not Sensitive.'"
    )
    |> validate_required([:attr_type],
      message: "The incident type must be set."
    )

    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive))
    |> Attribute.validate_attribute(Attribute.get_attribute(:type))
  end

  @doc """
  A changeset meant to be paired with bulk uploads.

  The import changeset simply runs the media through *every* attribute's changeset.
  In this way, it's possible to import any attribute.
  """
  def import_changeset(media, attrs) do
    # First, we rename and parse fields to match their internal representation.
    attr_names = Attribute.attribute_names(false, false) |> Enum.map(&(&1 |> to_string()))

    attrs =
      attrs
      |> Map.to_list()
      |> Enum.map(fn {k, v} ->
        if Enum.member?(attr_names, k) do
          attr = Attribute.get_attribute(k)

          # Split lists (comma separated)
          v =
            case attr.type do
              :multi_select ->
                if is_list(v) do
                  # Already split, or the uploader did something wrong (e.g., two columns of the same field)
                  v
                else
                  v |> String.split(",") |> Enum.map(&String.trim(&1))
                end

              _ ->
                v
            end

          {attr.schema_field |> to_string(), v}
        else
          {k, v}
        end
      end)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, k, v)
      end)

    Attribute.combined_changeset(media, Attribute.active_attributes(), attrs, nil, false)
  end

  def attribute_ratio(%Media{} = media) do
    length(Attribute.set_for_media(media)) / length(Attribute.attribute_names(false, false))
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
    # This logic would be nice to refactor into a `with` statement
    case Platform.Security.get_security_mode_state() do
      :normal ->
        case Enum.member?(user.restrictions || [], :muted) do
          true ->
            false

          false ->
            if Accounts.is_privileged(user) do
              true
            else
              not (Enum.member?(media.attr_restrictions || [], "Hidden") ||
                     Enum.member?(media.attr_restrictions || [], "Frozen") ||
                     media.attr_status == "Completed" || media.attr_status == "Cancelled")
            end
        end

      _ ->
        Accounts.is_admin(user)
    end
  end

  @doc """
  Can the user comment on the media?
  """
  def can_user_comment(%Media{} = media, %User{} = user) do
    case Platform.Security.get_security_mode_state() do
      :normal ->
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

      _ ->
        Accounts.is_admin(user)
    end
  end

  def can_user_create(%User{} = user) do
    case Platform.Security.get_security_mode_state() do
      :normal ->
        true

      _ ->
        Accounts.is_admin(user)
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

defimpl Jason.Encoder, for: Platform.Material.Media do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :slug,
        :attr_description,
        :attr_geolocation,
        :attr_geolocation_resolution,
        :attr_more_info,
        :attr_date,
        :attr_type,
        :attr_impact,
        :attr_equipment,
        :attr_restrictions,
        :attr_sensitive,
        :attr_status,
        :attr_tags,
        :versions,
        :inserted_at,
        :updated_at,
        :id
      ])
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end),
      opts
    )
  end
end
