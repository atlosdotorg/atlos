defmodule Platform.Material.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias Platform.Material

  use Memoize

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
    # boolean for deprecated attributes
    :deprecated,
    :add_none,
    :required_roles,
    :explanation_required,
    # for selects and multiple selects -- the values which require the user to have special privileges
    :privileged_values,
    # for selects and multiple selects
    :option_descriptions,
    # allows users to define their own options in a multi-select
    :allow_user_defined_options,
    # allows the attribute to be embedded on another attribute's edit pane (i.e., combine attributes)
    :parent
  ]

  defp renamed_attributes() do
    %{
      recorded_by: :camera_system,
      flag: :status,
      date_recorded: :date
    }
  end

  def attributes() do
    [
      %Attribute{
        schema_field: :attr_sensitive,
        type: :multi_select,
        options: [
          "Personal Information Visible",
          "Graphic Violence",
          "Deleted by Source",
          "Deceptive or Misleading"
        ],
        option_descriptions: %{
          "Personal Information Visible" => "Could identify individuals or their location",
          "Graphic Violence" => "Media contains violence or other graphic imagery",
          "Deleted by Source" => "The media has been deleted from its original location",
          "Deceptive or Misleading" =>
            "The media is a hoax, misinformation, or otherwise deceptive",
          "Not Sensitive" => "The media is not sensitive"
        },
        label: "Sensitivity",
        min_length: 1,
        pane: :metadata,
        required: true,
        name: :sensitive,
        add_none: "Not Sensitive",
        description:
          "Is this incident sensitive? This information helps us keep our community safe."
      },
      %Attribute{
        schema_field: :attr_description,
        type: :text,
        max_length: 240,
        min_length: 8,
        label: "Description",
        pane: :not_shown,
        required: true,
        name: :description
      },
      %Attribute{
        schema_field: :attr_type,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable
        options: [],
        label: "Incident Type",
        description: "What type of incident is this? Select all that apply.",
        pane: :attributes,
        required: true,
        name: :type
      },
      %Attribute{
        schema_field: :attr_impact,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable
        options: [],
        label: "Impact",
        description: "What is damaged, harmed, or lost in this incident?",
        pane: :attributes,
        required: false,
        name: :impact,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_equipment,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable
        options: [],
        label: "Equipment Used",
        description:
          "What equipment — weapon, military infrastructure, etc. — is used in the incident?",
        pane: :attributes,
        required: false,
        name: :equipment,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_time_of_day,
        type: :select,
        options: [],
        label: "Day/Night (Deprecated)",
        pane: :attributes,
        required: false,
        deprecated: true,
        name: :time_of_day
      },
      %Attribute{
        schema_field: :attr_geolocation,
        description:
          "For incidents that span multiple locations (e.g., movement down a street or a fire), choose a representative verifiable location. All geolocations must be confirmable visually.",
        type: :location,
        label: "Geolocation",
        pane: :attributes,
        required: false,
        name: :geolocation
      },
      %Attribute{
        schema_field: :attr_geolocation_resolution,
        type: :select,
        label: "Precision",
        pane: :not_shown,
        required: false,
        name: :geolocation_resolution,
        parent: :geolocation,
        options: [
          "Exact",
          "Vicinity",
          "Locality"
        ],
        option_descriptions: %{
          "Exact" => "Maximum precision (± 10m)",
          "Vicinity" => "Same complex, block, field, etc. (± 100m)",
          "Locality" => "Same neighborhood, village, etc. (± 1km)"
        }
      },
      %Attribute{
        schema_field: :attr_environment,
        type: :select,
        options: [],
        label: "Environment (Deprecated)",
        pane: :attributes,
        required: false,
        name: :environment,
        deprecated: true,
        description:
          "What is primarily in view? Note that this does not refer to where the media was captured."
      },
      %Attribute{
        schema_field: :attr_weather,
        type: :multi_select,
        options: [],
        label: "Weather (Deprecated)",
        pane: :attributes,
        required: false,
        name: :weather,
        deprecated: true,
        add_none: "Indeterminable"
      },
      %Attribute{
        schema_field: :attr_camera_system,
        type: :multi_select,
        options: [],
        label: "Camera System (Deprecated)",
        pane: :attributes,
        required: false,
        name: :camera_system,
        deprecated: true,
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
        options: [],
        label: "Civilian Impact (Deprecated)",
        pane: :attributes,
        required: false,
        name: :civilian_impact,
        deprecated: true,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_event,
        type: :multi_select,
        options: [],
        label: "Event (Deprecated)",
        pane: :attributes,
        required: false,
        name: :event,
        description: "What events are visible in the incident's media?",
        deprecated: true,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_casualty,
        type: :multi_select,
        options: [],
        label: "Casualty (Deprecated)",
        pane: :attributes,
        required: false,
        name: :casualty,
        deprecated: true,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_military_infrastructure,
        type: :multi_select,
        options: [],
        label: "Military Infrastructure (Deprecated)",
        pane: :attributes,
        required: false,
        name: :military_infrastructure,
        description: "What military infrastructure is visible in the media?",
        deprecated: true,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_weapon,
        type: :multi_select,
        options: [],
        label: "Weapon (Deprecated)",
        pane: :attributes,
        required: false,
        name: :weapon,
        description: "What weapons are visible in the incident's media?",
        deprecated: true,
        add_none: "None"
      },
      %Attribute{
        schema_field: :attr_time_recorded,
        type: :time,
        label: "Time Recorded (Deprecated)",
        pane: :attributes,
        required: false,
        name: :time_recorded,
        deprecated: true,
        description: "What time of day was the incident? Use the local timezone, if possible."
      },
      %Attribute{
        schema_field: :attr_date,
        type: :date,
        label: "Date",
        pane: :attributes,
        required: false,
        name: :date,
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
          "Completed" => "Investigation complete",
          "Cancelled" => "Will not be completed (out of scope, etc.)"
        }
      },
      %Attribute{
        schema_field: :attr_tags,
        type: :multi_select,
        label: "Tags",
        pane: :metadata,
        required: false,
        name: :tags,
        required_roles: [:admin, :trusted, :coordinator],
        allow_user_defined_options: true,
        description: "Use tags to help organize incidents on Atlos."
      }
    ]
  end

  @doc """
  Get all the active, non-deprecated attributes.
  """
  def active_attributes() do
    attributes() |> Enum.filter(&(&1.deprecated != true))
  end

  @doc """
  Get the names of the attributes that are available for the given media. Both nil and the empty list count as unset.
  """
  def set_for_media(media, pane \\ nil) do
    Enum.filter(attributes(), fn attr ->
      val = Map.get(media, attr.schema_field)
      val != nil && val != [] && (pane == nil || attr.pane == pane) && attr.deprecated != true
    end)
  end

  def unset_for_media(media, pane \\ nil) do
    set = set_for_media(media)

    attributes()
    |> Enum.filter(&(!Enum.member?(set, &1)))
    |> Enum.filter(&(&1.deprecated != true))
    |> Enum.filter(&(pane == nil || &1.pane == pane))
  end

  def attribute_names(include_renamed_attributes \\ true, include_deprecated_attributes \\ true) do
    (attributes()
     |> Enum.filter(&(&1.deprecated != true or include_deprecated_attributes))
     |> Enum.map(& &1.name)) ++
      if include_renamed_attributes, do: Map.keys(renamed_attributes()), else: []
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

    Enum.find(attributes(), &(&1.name |> to_string() == real_name))
  end

  def get_attribute_by_schema_field(name) do
    name = name |> to_string()
    Enum.find(attributes(), &(&1.schema_field |> to_string() == name))
  end

  def changeset(
        %Media{} = media,
        %Attribute{} = attribute,
        attrs \\ %{},
        user \\ nil,
        verify_change_exists \\ true,
        changeset \\ nil
      ) do
    (changeset || media)
    |> cast(%{}, [])
    |> populate_virtual_data(attribute)
    |> cast_attribute(attribute, attrs)
    |> validate_attribute(attribute, user)
    |> cast_and_validate_virtual_explanation(attrs, attribute)
    |> update_from_virtual_data(attribute)
    |> verify_user_can_edit(attribute, user, media)
    |> then(fn c ->
      if verify_change_exists, do: verify_change_exists(c, [attribute]), else: c
    end)
  end

  def combined_changeset(
        %Media{} = media,
        attributes,
        attrs \\ %{},
        user \\ nil,
        verify_change_exists \\ true
      ) do
    Enum.reduce(attributes, media, fn elem, acc ->
      changeset(media, elem, attrs, user, false, acc)
    end)
    |> then(fn c ->
      if verify_change_exists, do: verify_change_exists(c, attributes), else: c
    end)
  end

  def verify_user_can_edit(changeset, attribute, user, media) do
    if is_nil(user) || can_user_edit(attribute, user, media) do
      changeset
    else
      changeset
      |> Ecto.Changeset.add_error(
        attribute.schema_field,
        "You do not have permission to edit this attribute."
      )
    end
  end

  defp populate_virtual_data(changeset, %Attribute{} = attribute) do
    case attribute.type do
      :location ->
        with %Geo.Point{coordinates: {lon, lat}} <- get_field(changeset, attribute.schema_field) do
          changeset |> put_change(:location, to_string(lat) <> ", " <> to_string(lon))
        else
          _ -> changeset
        end

      _ ->
        changeset
    end
  end

  defp update_from_virtual_data(changeset, %Attribute{} = attribute) do
    case attribute.type do
      :location ->
        error_msg =
          "Unable to parse this location; please enter a latitude-longitude pair separated by commas."

        coords =
          (Map.get(changeset.changes, :location, changeset.data.location) || "")
          |> String.trim()
          |> String.split(",")

        case coords do
          [""] ->
            changeset
            |> put_change(attribute.schema_field, nil)

          [lat_string, lon_string] ->
            with {lat, ""} <- Float.parse(lat_string |> String.trim()),
                 {lon, ""} <- Float.parse(lon_string |> String.trim()) do
              changeset
              |> put_change(attribute.schema_field, %Geo.Point{
                coordinates: {lon, lat},
                srid: 4326
              })
            else
              _ ->
                changeset
                |> add_error(
                  attribute.schema_field,
                  error_msg
                )
            end

          _ ->
            changeset
            |> add_error(
              attribute.schema_field,
              error_msg
            )
        end

      _ ->
        changeset
    end
  end

  defp cast_attribute(media, %Attribute{} = attribute, attrs) do
    if attribute.deprecated == true do
      raise "cannot cast deprecated attribute"
    end

    media
    |> cast(attrs, [:explanation], message: "Unable to parse explanation.")
    |> then(fn changeset ->
      case attribute.type do
        # Explanation is a virtual field! We cast here so we can validate.
        # TODO: Is there an idiomatic way to clean this up?
        :location ->
          changeset
          |> cast(attrs, [:location])

        _ ->
          changeset
          |> cast(attrs, [attribute.schema_field])
      end
    end)
    |> then(fn changeset ->
      changeset
      |> Map.put(
        :errors,
        changeset.errors
        |> Enum.map(fn {attr, {error_message, metadata}} ->
          cond do
            attribute.type == :time and attr == attribute.schema_field ->
              {attr, {"Time must include an hour and minute.", metadata}}

            attribute.type == :date and attr == attribute.schema_field ->
              {attr,
               {"Verify the date is valid. Date must include a year, month, and day.", metadata}}

            true ->
              {attr, {error_message, metadata}}
          end
        end)
      )
    end)
  end

  defmemo get_custom_attribute_options(name) do
    extra = Jason.decode!(System.get_env("ATTRIBUTE_OPTIONS", "{}"))

    Map.get(extra, name |> to_string(), [])
  end

  def options(%Attribute{} = attribute, current_val \\ nil) do
    base_options = attribute.options || []

    base_options = base_options ++ get_custom_attribute_options(attribute.name)

    primary_options =
      if Attribute.allow_user_defined_options(attribute) and attribute.type == :multi_select do
        base_options ++ Material.get_values_of_attribute_cached(attribute)
      else
        base_options
      end

    base_options =
      if attribute.add_none do
        [attribute.add_none] ++ primary_options
      else
        primary_options
      end

    if is_list(current_val) do
      base_options ++ current_val
    else
      base_options
    end
  end

  def validate_attribute(changeset, %Attribute{} = attribute, user \\ nil) do
    validations =
      case attribute.type do
        :multi_select ->
          if Attribute.allow_user_defined_options(attribute) == true do
            # If `allow_user_defined_options` is unset or false, verify that the
            # values are a subset of the options.
            changeset
          else
            changeset
            |> validate_subset(attribute.schema_field, options(attribute),
              message:
                "Includes an invalid value. Valid values are: " <>
                  Enum.join(options(attribute), ", ")
            )
          end
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
          |> validate_inclusion(attribute.schema_field, options(attribute),
            message:
              "Includes an invalid value. Valid values are: " <>
                Enum.join(options(attribute), ", ")
          )
          |> validate_privileged_values(attribute, user)

        :text ->
          changeset
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )

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

          if not Enum.empty?(requires_privilege) do
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
    # When attribute and user aren't provided, or there are no privileged values,
    # then there is nothing to validate.

    changeset
  end

  defp verify_change_exists(changeset, attributes) do
    if not Enum.any?(attributes, &Map.has_key?(changeset.changes, &1.schema_field)) do
      changeset
      |> add_error(hd(attributes).schema_field, "A change is required to post an update.")
    else
      changeset
    end
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
          "Needs Upload" -> "~purple"
          _ -> "~warning"
        end

      _ ->
        "~neutral"
    end
  end

  def allow_user_defined_options(%Attribute{allow_user_defined_options: true}) do
    true
  end

  def allow_user_defined_options(%Attribute{}) do
    false
  end

  def requires_privileges_to_edit(%Attribute{} = attr) do
    is_list(attr.required_roles) and not Enum.empty?(attr.required_roles)
  end

  @doc """
  Get the child attributes of the given parent attribute.
  """
  def get_children(parent_name) do
    attributes() |> Enum.filter(&(&1.parent == parent_name))
  end
end
