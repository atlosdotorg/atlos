defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils
  alias Platform.Material.Attribute
  alias Platform.Material.MediaSubscription
  alias Platform.Projects
  alias Platform.Permissions
  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "media" do
    # Core uneditable data
    field(:slug, :string, autogenerate: {Utils, :generate_media_slug, []})
    field(:deleted, :boolean, default: false)

    # Core Attributes
    field(:attr_description, :string)
    field(:attr_geolocation, Geo.PostGIS.Geometry)
    field(:attr_geolocation_resolution, :string)
    field(:attr_more_info, :string)
    field(:attr_general_location, :string)
    field(:attr_date, :date)
    field(:attr_time, :time)
    field(:attr_type, {:array, :string})
    field(:attr_impact, {:array, :string})
    field(:attr_equipment, {:array, :string})

    # The ID (primary key) must match the ID of the attribute
    @primary_key {:id, :binary_id, autogenerate: false}
    embeds_many :project_attributes, ProjectAttributeValue, on_replace: :raise do
      belongs_to(:project, Projects.Project, type: :binary_id)
      field(:value, Platform.FlexibleJSONType, default: nil)
      field(:explanation, :string, virtual: true)
    end

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
    field(:attr_restrictions, {:array, :string})
    field(:attr_sensitive, {:array, :string})
    field(:attr_status, :string)
    field(:attr_tags, {:array, :string})

    # Assignees
    has_many(:attr_assignments, Platform.Material.MediaAssignment,
      on_replace: :delete,
      foreign_key: :media_id
    )

    # Automatically-generated Metadata
    field(:auto_metadata, :map, default: %{})

    # Virtual attributes for updates + multi-part attributes
    field(:explanation, :string, virtual: true)
    field(:location, :string, virtual: true)
    # For the input value from the client (JSON array)
    field(:urls, :string, virtual: true)
    # For the internal, parsed representation
    field(:urls_parsed, {:array, :string}, virtual: true)

    # Virtual attributes for population during querying
    field(:has_unread_notification, :boolean, virtual: true, default: false)
    field(:has_subscription, :boolean, virtual: true, default: false)
    field(:is_assigned, :boolean, virtual: true, default: false)
    field(:display_color, :string, virtual: true)

    # Refers to the post date of the most recent associated update -- this is distinct from `updated_at`
    field(:last_update_time, :utc_datetime, virtual: true)

    # Metadata
    timestamps()

    # Computed tsvector fields "searchable" and "searchable_text"; we tell Ecto it's an array of maps so we can use it in queries
    # tsvector'ized version of searchable_text
    field(:searchable, {:array, :map}, load_in_query: false)
    field(:searchable_text, :string, load_in_query: false)

    # Associations
    has_many(:versions, Platform.Material.MediaVersion)
    has_many(:notifications, Platform.Notifications.Notification)
    has_many(:updates, Platform.Updates.Update)
    has_many(:subscriptions, MediaSubscription)
    belongs_to(:project, Platform.Projects.Project, type: :binary_id)
  end

  @doc false
  def changeset(media, attrs, user \\ nil) do
    media
    |> cast(attrs, [
      :attr_description,
      :attr_sensitive,
      :attr_status,
      :attr_date,
      :deleted,
      :project_id,
      :urls,
      :location
    ])
    |> validate_required([:project_id], message: "Please select a project")
    |> populate_geolocation()
    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:description), media,
      user: user,
      required: true
    )
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive), media,
      user: user,
      required: true
    )
    |> Attribute.validate_attribute(Attribute.get_attribute(:date), media,
      user: user,
      required: false
    )
    |> validate_project(user, media)
    |> parse_and_validate_validate_json_array(:urls, :urls_parsed)
    |> validate_url_list(:urls_parsed)
    |> then(fn cs ->
      project_id = Ecto.Changeset.get_field(cs, :project_id)
      project = Projects.get_project(project_id)

      if is_nil(project),
        do: cs,
        else:
          Platform.Material.change_media_attributes(
            cs.data |> Map.put(:project, project) |> Map.put(:project_id, project.id),
            Projects.get_project_attributes(project),
            attrs,
            changeset: cs,
            user: user,
            verify_change_exists: false
          )
    end)
    |> then(fn cs ->
      project_id = Ecto.Changeset.get_field(cs, :project_id, nil)

      attr =
        Attribute.get_attribute(:tags,
          project: Ecto.Changeset.get_field(cs, :project_id, nil) |> Projects.get_project()
        )

      # We manually insert the project ID because the media hasn't been inserted yet,
      # so we can't get it from the media itself. Still, we want to check the user's permissions.
      if !is_nil(user) &&
           Permissions.can_edit_media?(user, %{media | project_id: project_id}, attr) do
        cs
        # TODO: This is a good refactoring opportunity with the logic above
        |> cast(attrs, [:attr_tags])
        |> Attribute.validate_attribute(Attribute.get_attribute(:tags), media,
          user: user,
          required: false
        )
      else
        cs
      end
    end)
  end

  defp populate_geolocation(changeset) do
    case get_change(changeset, :location) do
      nil ->
        changeset

      _ ->
        Attribute.update_from_virtual_data(changeset, Attribute.get_attribute(:geolocation))
    end
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

  def validate_project(changeset, user \\ nil, media \\ nil) do
    project_id = Ecto.Changeset.get_change(changeset, :project_id, :no_change)
    original_project_id = changeset.data.project_id

    case project_id do
      :no_change ->
        changeset

      new_project_id ->
        new_project = Projects.get_project(new_project_id)
        original_project = Projects.get_project(original_project_id)

        cond do
          !is_nil(media) && !is_nil(user) && !Permissions.can_edit_media?(user, media) ->
            changeset
            |> add_error(:project_id, "You cannot edit this incidents's project.")

          !is_nil(project_id) && is_nil(new_project) ->
            changeset
            |> add_error(:project_id, "Project does not exist")

          !is_nil(user) && !is_nil(new_project) &&
              !Permissions.can_add_media_to_project?(user, new_project) ->
            changeset
            |> add_error(:project_id, "You cannot add incidents to this project.")

          !is_nil(user) && !is_nil(original_project) ->
            changeset
            |> add_error(:project_id, "You cannot remove media from projects!")

          is_nil(new_project) ->
            changeset
            |> add_error(:project_id, "You must select a project.")

          true ->
            changeset
        end
    end
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
    |> validate_project(user, media)
  end

  @doc """
  A changeset meant to be paired with bulk uploads.

  The import changeset simply runs the media through *every* attribute's changeset.
  In this way, it's possible to import any attribute.
  """
  def import_changeset(media, attrs, %Projects.Project{} = project) do
    possible_attrs = Attribute.active_attributes(project: project)

    # If "latitude" and "longitude" are present, we need to combine them into a single
    # "geolocation" field.
    attrs =
      case {Map.get(attrs, "latitude"), Map.get(attrs, "longitude")} do
        {nil, nil} ->
          attrs

        {"", ""} ->
          attrs

        {lat, lon} ->
          # Remove all non-numeric characters
          lat = String.replace(lat, ~r/[^0-9.-]/, "")
          lon = String.replace(lon, ~r/[^0-9.-]/, "")

          attrs
          |> Map.put("location", "#{lat},#{lon}")
          |> Map.delete("latitude")
          |> Map.delete("longitude")
      end

    # First, we rename and parse fields to match their internal representation.
    attrs =
      Enum.map(attrs, fn {k, v} ->
        attr =
          Enum.find(possible_attrs, fn a ->
            # We allow the user to use the schema field, the attribute name, or the standardized name
            to_string(a.schema_field) == k or to_string(a.schema_field) == "attr_" <> k or
              String.downcase(Attribute.standardized_label(a, project: project)) ==
                String.downcase(k)
          end)

        if is_nil(attr) do
          {to_string(k), v}
        else
          # Split lists (comma separated)
          v =
            case attr.type do
              :multi_select ->
                if is_list(v) do
                  # Already split, or the uploader did something wrong (e.g., two columns of the same field)
                  v
                else
                  v |> String.split(",") |> Enum.map(&String.trim(&1)) |> Enum.reject(&(&1 == ""))
                end

              :multi_users ->
                v
                |> String.split(",")
                |> Enum.map(&String.trim(&1))
                |> Enum.reject(&(&1 == ""))
                |> Enum.map(fn username ->
                  user = Platform.Accounts.get_user_by_username(username)

                  if is_nil(user) do
                    nil
                  else
                    user.id
                  end
                end)
                |> Enum.reject(&is_nil/1)

              _ ->
                v
            end

          name =
            if attr.schema_field == :project_attributes,
              do: {:project_attribute, attr.name},
              else: attr.schema_field

          {name, v}
        end
      end)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case k do
          {:project_attribute, name} ->
            # Project attributes are stored in a special map
            existing = Map.get(acc, "project_attributes", %{})

            Map.put(
              acc,
              "project_attributes",
              existing
              |> Map.put(to_string(map_size(existing)), %{
                "id" => name,
                "value" => v,
                "project_id" => project.id
              })
            )

          _ ->
            # Everything else is stored in a normal base map
            Map.put(acc, to_string(k), v)
        end
      end)

    # Move attributes
    Attribute.combined_changeset(media, Attribute.active_attributes(project: project), attrs,
      verify_change_exists: false
    )
    |> Ecto.Changeset.put_change(:project_id, project.id)
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
    Utils.text_search(search_terms, queryable, search_literal: true)
  end

  def slug_to_display(media) do
    case media.project do
      nil -> media.slug |> String.replace("ATL-", "")
      %Ecto.Association.NotLoaded{} -> media.slug |> String.replace("ATL-", "")
      proj -> proj.code <> "-" <> (media.slug |> String.replace("ATL-", ""))
    end
  end
end

defimpl Jason.Encoder, for: Platform.Material.Media do
  def insert_deprecated_attributes(map, %Platform.Material.Media{} = media) do
    # When we added custom attributes, we migrated some attributes that were previously "core"
    # attributes to the custom attribute system. This function looks for those attributes
    # and inserts their "correct" versions into the map.

    migrated_pairs = Platform.Utils.migrated_attributes(media)

    Enum.reduce(migrated_pairs, map, fn {old_attr, new_attr}, map ->
      Map.put(map, old_attr.schema_field, Platform.Material.get_attribute_value(media, new_attr))
    end)
  end

  def insert_custom_attributes(map, %Platform.Material.Media{} = media) do
    project_attributes = if is_nil(media.project), do: [], else: media.project.attributes

    project_attributes = Enum.filter(project_attributes, & &1.enabled)

    values =
      Enum.map(project_attributes, fn attr ->
        %{
          name: attr.name,
          id: attr.id,
          value:
            Platform.Material.get_attribute_value(
              media,
              Platform.Projects.ProjectAttribute.to_attribute(attr)
            )
        }
      end)

    Map.put(map, "project_attributes", values)
  end

  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :slug,
        :attr_description,
        :attr_geolocation,
        :attr_geolocation_resolution,
        :attr_more_info,
        :attr_date,
        :attr_restrictions,
        :attr_sensitive,
        :attr_status,
        :attr_tags,
        # TODO: Remove this once we're sure we don't need it (i.e., after legacy API is removed)
        :versions,
        :inserted_at,
        :updated_at,
        :deleted,
        :project,
        :id
      ])
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end)
      |> Map.put(:source_material, value.versions)
      # TODO: Remove this once we're sure we don't need it (i.e., after legacy API is removed)
      |> insert_deprecated_attributes(value)
      |> insert_custom_attributes(value),
      opts
    )
  end
end
