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
    field :deleted, :boolean, default: false

    # Core Attributes
    field :attr_description, :string
    field :attr_geolocation, Geo.PostGIS.Geometry
    field :attr_geolocation_resolution, :string
    field :attr_more_info, :string
    field :attr_general_location, :string
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

    # Automatically-generated Metadata
    field :auto_metadata, :map, default: %{}

    # Virtual attributes for updates + multi-part attributes
    field :explanation, :string, virtual: true
    field :location, :string, virtual: true
    # For the input value from the client (JSON array)
    field :urls, :string, virtual: true
    # For the internal, parsed representation
    field :urls_parsed, {:array, :string}, virtual: true

    # Virtual attributes for population during querying
    field :has_unread_notification, :boolean, virtual: true, default: false
    field :has_subscription, :boolean, virtual: true, default: false

    # Refers to the post date of the most recent associated update -- this is distinct from `updated_at`
    field :last_update_time, :utc_datetime, virtual: true

    # Metadata
    timestamps()

    # Associations
    has_many :versions, Platform.Material.MediaVersion
    has_many :updates, Platform.Updates.Update
    has_many :subscriptions, MediaSubscription
    belongs_to :project, Platform.Projects.Project
  end

  @doc false
  def changeset(media, attrs, user \\ nil) do
    media
    |> cast(attrs, [
      :attr_description,
      :attr_sensitive,
      :attr_status,
      :attr_type,
      :attr_equipment,
      :attr_impact,
      :attr_date,
      :attr_general_location,
      :deleted,
      :urls
    ])

    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:description), user, true)
    |> Attribute.validate_attribute(Attribute.get_attribute(:type), user, true)
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive), user, true)
    |> Attribute.validate_attribute(Attribute.get_attribute(:equipment), user, false)
    |> Attribute.validate_attribute(Attribute.get_attribute(:impact), user, false)
    |> Attribute.validate_attribute(Attribute.get_attribute(:date), user, false)
    |> Attribute.validate_attribute(Attribute.get_attribute(:general_location), user, false)
    |> parse_and_validate_validate_json_array(:urls, :urls_parsed)
    |> validate_url_list(:urls_parsed)
    |> then(fn cs ->
      attr = Attribute.get_attribute(:tags)

      if !is_nil(user) && Attribute.can_user_edit(attr, user, media) do
        cs
        # TODO: This is a good refactoring opportunity with the logic above
        |> cast(attrs, [:attr_tags])
        |> Attribute.validate_attribute(Attribute.get_attribute(:tags), user, false)
      else
        cs
      end
    end)
  end

  def parse_and_validate_validate_json_array(changeset, field, dest) when is_atom(field) do
    # Validate
    changeset =
      validate_change(changeset, field, fn field, value ->
        if not is_nil(value) do
          with {:ok, parsed_val} <- Jason.decode(value),
               true <- is_list(parsed_val) do
            []
          else
            _ -> [{field, "Invalid list"}]
          end
        end
      end)

    # Parse
    value = Ecto.Changeset.get_change(changeset, field)

    changeset =
      Ecto.Changeset.put_change(
        changeset,
        dest,
        with false <- is_nil(value),
             {:ok, parsed_val} <- Jason.decode(value),
             true <- is_list(parsed_val) do
          parsed_val
        else
          _ -> []
        end
      )

    changeset
  end

  def validate_url_list(changeset, field) do
    valid? = fn url ->
      uri = URI.parse(url)
      uri.scheme != nil && uri.host =~ "."
    end

    validate_change(changeset, field, fn field, value ->
      if is_list(value) do
        if Enum.all?(value, valid?) do
          []
        else
          [
            {field,
             "The following entries are not valid urls: " <>
               (Enum.filter(value, &(not valid?.(&1))) |> Enum.join(", "))}
          ]
        end
      end
    end)
  end

  @doc """
  A changeset meant to be used with projects.
  """
  def project_changeset(media, attrs, user \\ nil) do
    media
    |> cast(attrs, [:project_id])

    # Only continue if :project_id is in the changes
    |> then(fn cs ->
      if Ecto.Changeset.get_change(cs, :project_id, :no_change) != :no_change do
        cs
        |> validate_change(:project_id, fn _, value ->
          if !is_nil(value) && is_nil(Platform.Projects.get_project!(value)) do
            [{:project_id, "Project does not exist"}]
          else
            []
          end
        end)
        |> validate_change(:project_id, fn _, value ->
          if is_nil(user) do
            []
          else
            case Platform.Projects.can_edit_media?(user, Platform.Projects.get_project!(value)) &&
                   (is_nil(media.project_id) ||
                      Platform.Projects.can_edit_media?(
                        user,
                        Platform.Projects.get_project!(media.project_id)
                      )) do
              true ->
                []

              false ->
                [{:project_id, "You do not have permission to manage incidents in this project"}]
            end
          end
        end)
      else
        cs
      end
    end)
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
    case {media.attr_restrictions, media.deleted} do
      {nil, false} ->
        true

      {_, true} ->
        Enum.member?(user.roles || [], :admin)

      {values, false} ->
        # Restrictions are present.
        if Enum.member?(values, "Hidden") do
          Accounts.is_privileged(user)
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

  @doc """
  Perform a text search on the given queryable. Will also query associated media versions.
  """
  def text_search(search_terms, queryable \\ Media) do
    media_via_associated_media_versions =
      from version in subquery(
             Utils.text_search(search_terms, Platform.Material.MediaVersion, literal: true)
           ),
           where: version.visibility == :visible,
           join: media in assoc(version, :media),
           select: media

    from u in subquery(
           Ecto.Query.union(
             Utils.text_search(search_terms, queryable),
             ^media_via_associated_media_versions
           )
         ),
         select: u
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
        :deleted,
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
