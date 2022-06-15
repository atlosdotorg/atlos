defmodule Platform.Material.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts

  defstruct [
    :schema_field,
    :type,
    :label,
    :options,
    :max_length,
    :min_length,
    :pane,
    :required,
    :custom_validation,
    :name,
    :description,
    :add_none,
    :required_roles,
    :explanation_required,
    # for selects and multiple selects -- the values which require the user to have special privileges
    :privileged_values,
    # for selects and multiple selects
    :option_descriptions
  ]

  defp renamed_attributes() do
    %{
      recorded_by: :camera_system,
      flag: :status
    }
  end

  defp attributes() do
    [
      %Attribute{
        schema_field: :attr_sensitive,
        type: :multi_select,
        options: [
          "Threatens Civilian Safety",
          "Graphic Violence",
          "Deleted by Source",
          "Deceptive or Misleading"
        ],
        label: "Sensitivity",
        min_length: 1,
        pane: :metadata,
        required: true,
        name: :sensitive,
        add_none: "Not Sensitive"
      },
      %Attribute{
        schema_field: :description,
        type: :text,
        max_length: 240,
        min_length: 8,
        label: "Description",
        pane: :attributes,
        required: true,
        name: :description
      },
      %Attribute{
        schema_field: :attr_time_of_day,
        type: :select,
        options: ["Night", "Day"],
        label: "Day/Night",
        pane: :attributes,
        required: false,
        name: :time_of_day
      },
      %Attribute{
        schema_field: :attr_geolocation,
        type: :location,
        label: "Geolocation",
        pane: :attributes,
        required: false,
        name: :geolocation
      },
      %Attribute{
        schema_field: :attr_environment,
        type: :select,
        options: ["Inside", "Outside"],
        label: "Environment",
        pane: :attributes,
        required: false,
        name: :environment,
        description:
          "What is primarily in view? Note that this does not refer to where the media was captured."
      },
      %Attribute{
        schema_field: :attr_weather,
        type: :multi_select,
        options: ["Sunny", "Partly Cloudly", "Overcast", "Raining", "Snowing"],
        label: "Weather",
        pane: :attributes,
        required: false,
        name: :weather,
        add_none: "Indeterminable"
      },
      %Attribute{
        schema_field: :attr_camera_system,
        type: :multi_select,
        options: ["Handheld", "Satellite", "Surveillance Camera", "Drone", "Dashcam", "Other"],
        label: "Camera System",
        pane: :attributes,
        required: false,
        name: :camera_system,
        description:
          "What kinds of camera systems does the media use? If there are multiple pieces of media, select all that apply."
      },
      %Attribute{
        schema_field: :attr_more_info,
        type: :text,
        max_length: 3000,
        label: "More Info",
        pane: :attributes,
        required: false,
        name: :more_info,
        description: "For example, information noted by the source."
      },
      %Attribute{
        schema_field: :attr_civilian_impact,
        type: :multi_select,
        options: [
          "Structure/Residential",
          "Structure/Residential/House",
          "Structure/Residential/Apartment",
          "Structure/Healthcare",
          "Structure/School or Childcare",
          "Structure/Park or Playground",
          "Structure/Cultural",
          "Structure/Religious",
          "Structure/Industrial",
          "Structure/Administrative",
          "Structure/Commercial",
          "Structure/Airport",
          "Structure/Transit Station",
          "Vehicle/Car",
          "Vehicle/Train",
          "Vehicle/Bus",
          "Vehicle/Aircraft",
          "Vehicle/Boat"
        ],
        label: "Civilian Impact",
        pane: :attributes,
        required: false,
        name: :civilian_impact,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_event,
        type: :multi_select,
        options: [
          "Explosion",
          "Debris",
          "Fire",
          "Fire Damage",
          "Smoke",
          "Projectile Launching",
          "Projectile Striking",
          "Execution",
          "Combat",
          "Protest",
          "Civilian-Military Interaction"
        ],
        label: "Event",
        pane: :attributes,
        required: false,
        name: :event,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_casualty,
        type: :multi_select,
        options: [
          "Injured Person",
          "Injured Person/Civilian",
          "Injured Person/Soldier",
          "Killed Person",
          "Killed Person/Civilian",
          "Killed Person/Soldier",
          "Mass Grave"
        ],
        label: "Casualty",
        pane: :attributes,
        required: false,
        name: :casualty,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_military_infrastructure,
        type: :multi_select,
        options: [
          "Land-Based Vehicle",
          "Ship",
          "Aircraft",
          "Aircraft/Fighter",
          "Aircraft/Bomber",
          "Aircraft/Helicopter",
          "Aircraft/Drone",
          "Convoy",
          "Encampment"
        ],
        label: "Military Infrastructure",
        pane: :attributes,
        required: false,
        name: :military_infrastructure,
        description: "What military infrastructure is visibile in the media?",
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_weapon,
        type: :multi_select,
        options: [
          "Small Arm",
          "Launch System",
          "Launch System/Artillery",
          "Launch System/Self-Propelled",
          "Launch System/Multiple Launch Rocket System (MLRS)",
          "Munition",
          "Munition/Cluster",
          "Munition/Chemical",
          "Munition/Thermobaric",
          "Munition/Incendiary"
        ],
        label: "Weapon",
        pane: :attributes,
        required: false,
        name: :weapon,
        description: "What weapons are involved in the incident?",
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_time_recorded,
        type: :time,
        label: "Time Recorded",
        pane: :attributes,
        required: false,
        name: :time_recorded,
        description: "What time of day was the incident? Use the local timezone, if possible."
      },
      %Attribute{
        schema_field: :attr_date_recorded,
        type: :date,
        label: "Date Recorded",
        pane: :attributes,
        required: false,
        name: :date_recorded,
        description: "On what date did the incident take place?"
      },
      %Attribute{
        schema_field: :attr_restrictions,
        type: :multi_select,
        label: "Restrictions",
        pane: :metadata,
        required: false,
        name: :restrictions,
        # NOTE: Editing these values also requires editing the perm checks in `media.ex`
        options: ["Frozen", "Hidden"],
        required_roles: [:admin]
      },
      %Attribute{
        schema_field: :attr_status,
        type: :select,
        options: [
          "Unclaimed",
          "Claimed",
          "Help Needed",
          "Ready for Review",
          "Completed",
          "Cancelled"
        ],
        label: "Status",
        pane: :metadata,
        required: true,
        name: :status,
        description: "Use the status to help coordinate and track work on Atlos.",
        privileged_values: ["Completed", "Cancelled"],
        option_descriptions: %{
          "Unclaimed" => "Not actively being worked on",
          "Claimed" => "Actively being worked on",
          "Help Needed" => "Stuck, or second opinion needed",
          "Ready for Review" => "Ready for a moderator's verification",
          "Completed" => "Investigation complete (only moderators can set)",
          "Cancelled" => "Will not be completed (out of scope, etc.)"
        }
      }
    ]
  end

  @doc """
  Get the names of the attributes that are available for the given media.
  """
  def set_for_media(media, pane \\ nil) do
    Enum.filter(attributes(), fn attr ->
      Map.get(media, attr.schema_field) != nil && (pane == nil || attr.pane == pane)
    end)
  end

  def unset_for_media(media, pane \\ nil) do
    set = set_for_media(media)

    attributes()
    |> Enum.filter(&(!Enum.member?(set, &1)))
    |> Enum.filter(&(pane == nil || &1.pane == pane))
  end

  def attribute_names() do
    (attributes() |> Enum.map(& &1.name)) ++ Map.keys(renamed_attributes())
  end

  def attribute_schema_fields() do
    attributes() |> Enum.map(& &1.schema_field)
  end

  def get_attribute(name) do
    # Some attributes have been renamed; this allows us to keep updates
    # that reference the old name working.
    real_name =
      case renamed_attributes() do
        %{^name => new_name} -> new_name
        _ -> name
      end
      |> to_string()

    hd(Enum.filter(attributes(), &(&1.name |> to_string() == real_name)))
  end

  def changeset(media, %Attribute{} = attribute, attrs \\ %{}, user \\ nil) do
    media
    |> populate_virtual_data(attribute)
    |> cast_attribute(attribute, attrs)
    |> validate_attribute(attribute, user)
    |> cast_and_validate_virtual_explanation(attrs, attribute)
    |> update_from_virtual_data(attribute)
  end

  defp populate_virtual_data(%Media{} = media, %Attribute{} = attribute) do
    case attribute.type do
      :location ->
        with %Geo.Point{coordinates: {lon, lat}} <- Map.get(media, attribute.schema_field) do
          media |> Map.put(:latitude, lat) |> Map.put(:longitude, lon)
        else
          _ -> media
        end

      _ ->
        media
    end
  end

  defp update_from_virtual_data(changeset, %Attribute{} = attribute) do
    case attribute.type do
      :location ->
        lat = Map.get(changeset.changes, :latitude, changeset.data.latitude)
        lon = Map.get(changeset.changes, :longitude, changeset.data.longitude)

        if is_nil(lat) or is_nil(lon) do
          changeset
          |> put_change(attribute.schema_field, nil)
        else
          changeset
          |> put_change(attribute.schema_field, %Geo.Point{coordinates: {lon, lat}, srid: 4326})
        end

      _ ->
        changeset
    end
  end

  defp cast_attribute(media, %Attribute{} = attribute, attrs) do
    case attribute.type do
      # Explanation is a virtual field! We cast here so we can validate.
      :location -> media |> cast(attrs, [:latitude, :longitude, :explanation])
      _ -> media |> cast(attrs, [attribute.schema_field, :explanation])
    end
  end

  def options(%Attribute{} = attribute) do
    if attribute.add_none do
      [attribute.add_none] ++ attribute.options
    else
      attribute.options
    end
  end

  def validate_attribute(changeset, %Attribute{} = attribute, user \\ nil) do
    validations =
      case attribute.type do
        :multi_select ->
          changeset
          |> validate_subset(attribute.schema_field, options(attribute))
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )
          |> validate_change(attribute.schema_field, fn _, vals ->
            if attribute.add_none && Enum.member?(vals, attribute.add_none) && length(vals) > 1 do
              [
                {attribute.schema_field,
                 "If '#{attribute.add_none}' is selected, no other options are allowed."}
              ]
            else
              []
            end
          end)
          |> validate_privileged_values(attribute, user)

        :select ->
          changeset
          |> validate_inclusion(attribute.schema_field, options(attribute))
          |> validate_privileged_values(attribute, user)

        :text ->
          changeset
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )

        :location ->
          lat = Map.get(changeset.changes, :latitude, changeset.data.latitude)
          lon = Map.get(changeset.changes, :longitude, changeset.data.longitude)

          if is_nil(lon) != is_nil(lat) do
            changeset
            |> add_error(
              :longitude,
              "Both latitude and longitude are required. To clear the geolocation, set both latitude and longitude to blank."
            )
          else
            changeset
          end

        _ ->
          changeset
      end

    custom =
      if attribute.custom_validation != nil do
        validations |> validate_change(attribute.schema_field, attribute.custom_validation)
      else
        validations
      end

    if attribute.required do
      custom |> validate_required([attribute.schema_field])
    else
      custom
    end
  end

  defp cast_and_validate_virtual_explanation(changeset, params, attribute) do
    change =
      changeset
      |> cast(params, [:explanation])
      |> validate_length(:explanation,
        max: 2500,
        message: "Explanations cannot exceed 2500 characters."
      )

    if attribute.explanation_required do
      change
      |> validate_required(:explanation,
        message: "An explanation is required to update this attribute."
      )
      |> validate_length(:explanation,
        min: 10,
        message: "An explanation of at least 10 characters is required to update this attribute."
      )
    else
      change
    end
  end

  defp validate_privileged_values(changeset, %Attribute{} = attribute, %User{} = user)
       when is_list(attribute.privileged_values) do
    if Accounts.is_privileged(user) do
      # Changes by a privileged user can do anything
      changeset
    else
      values = attribute.privileged_values

      case get_field(changeset, attribute.schema_field) do
        v when is_list(v) ->
          requires_privilege =
            MapSet.intersection(Enum.into(v, MapSet.new()), Enum.into(values, MapSet.new()))

          if length(requires_privilege) > 0 do
            changeset
            |> add_error(
              attribute.schema_field,
              "Only moderators can set the following values: " <>
                Enum.join(requires_privilege, ", ")
            )
          else
            changeset
          end

        v ->
          if Enum.member?(values, v) do
            changeset
            |> add_error(
              attribute.schema_field,
              "Only moderators can set the value to '" <> v <> "'"
            )
          else
            changeset
          end
      end
    end
  end

  defp validate_privileged_values(changeset, _attribute, _user) do
    changeset
  end

  @doc """
  Can the given user edit the given attribute for the given media? This also checks
  whether they are allowed to edit the given media.
  """
  def can_user_edit(%Attribute{} = attribute, %User{} = user, %Media{} = media) do
    user_roles = user.roles || []

    with true <- Media.can_user_edit(media, user) do
      case attribute.required_roles || [] do
        [] -> true
        [hd | tail] -> Enum.any?([hd] ++ tail, &Enum.member?(user_roles, &1))
      end
    else
      _ -> false
    end
  end

  def attr_color(name, value) do
    case name do
      :sensitive ->
        "~critical"

      :status ->
        case value do
          "Unclaimed" -> "~positive"
          "Claimed" -> "~urge"
          "Cancelled" -> "~neutral"
          "Ready for Review" -> "~cyan"
          "Completed" -> "~purple"
          _ -> "~warning"
        end

      _ ->
        "~neutral"
    end
  end
end
