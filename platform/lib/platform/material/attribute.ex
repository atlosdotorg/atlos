defmodule Platform.Material.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Accounts.User
  alias Platform.Accounts
  alias Platform.Material
  alias Platform.Permissions

  alias Platform.Projects.ProjectAttribute

  use Memoize

  defstruct [
    :schema_field,
    :type,
    :label,
    :options,
    :max_length,
    :min_length,
    :pane,
    # Allows :text to be input as :short_text or :textarea (default)
    :input_type,
    :required,
    :custom_validation,
    # This is an internal ID; it is used in URLs. For custom attributes, this is a binary ID.
    :name,
    :description,
    # boolean for deprecated attributes
    :deprecated,
    :add_none,
    :is_restricted,
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

  def attributes(opts \\ []) do
    project = Keyword.get(opts, :project)

    project_attrs =
      if project do
        Enum.map(project.attributes, &ProjectAttribute.to_attribute/1)
      else
        []
      end

    core_attrs = [
      %Attribute{
        schema_field: :attr_status,
        type: :select,
        options: [
          "Unclaimed",
          "In Progress",
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
          "In Progress" => "Actively being worked on",
          "Help Needed" => "Stuck, or second opinion needed",
          "Ready for Review" => "Ready for a moderator's verification",
          "Completed" => "Investigation complete",
          "Cancelled" => "Will not be completed (out of scope, etc.)"
        }
      },
      %Attribute{
        schema_field: :attr_description,
        type: :text,
        max_length: 240,
        min_length: 8,
        label: "Description",
        pane: :not_shown,
        required: true,
        name: :description,
        description: "A short description of the incident."
      },
      %Attribute{
        schema_field: :attr_date,
        type: :date,
        label: "Date",
        pane: :attributes,
        required: false,
        name: :date,
        description: "On what date did the incident take place?"
      }
    ]

    secondary_attrs = [
      %Attribute{
        schema_field: :attr_general_location,
        type: :text,
        input_type: :short_text,
        max_length: 240,
        min_length: 2,
        label: "Reported Near",
        pane: :attributes,
        required: false,
        name: :general_location,
        deprecated: true
      },
      %Attribute{
        schema_field: :attr_tags,
        type: :multi_select,
        label: "Tags",
        pane: :metadata,
        required: false,
        name: :tags,
        is_restricted: true,
        allow_user_defined_options: true,
        description: "Use tags to help organize incidents on Atlos."
      },
      %Attribute{
        schema_field: :attr_type,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable to override
        options: [
          "Military Activity",
          "Military Activity/Movement",
          "Military Activity/Equipment",
          "Military Activity/Equipment/Lost",
          "Military Activity/Execution",
          "Military Activity/Combat",
          "Military Activity/Encampment",
          "Military Activity/Strike",
          "Military Activity/Explosion",
          "Military Activity/Detention",
          "Military Activity/Mass Grave",
          "Military Activity/Demolition",
          "Civilian Activity",
          "Civilian Activity/Protest or March",
          "Civilian Activity/Riot",
          "Civilian Activity/Violence",
          "Policing",
          "Policing/Use of Force",
          "Policing/Detention",
          "Weather",
          "Weather/Flooding",
          "Weather/Hurricane",
          "Weather/Fire",
          "Other"
        ],
        label: "Incident Type",
        description: "What type of incident is this? Select all that apply.",
        pane: :attributes,
        required: true,
        name: :type,
        deprecated: true
      },
      %Attribute{
        schema_field: :attr_impact,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable to override
        options: [
          "Structure",
          "Structure/Residential",
          "Structure/Residential/House",
          "Structure/Residential/Apartment",
          "Structure/Healthcare",
          "Structure/Humanitarian",
          "Structure/Food Infrastructure",
          "Structure/School or Childcare",
          "Structure/Park or Playground",
          "Structure/Cultural",
          "Structure/Religious",
          "Structure/Industrial",
          "Structure/Administrative",
          "Structure/Commercial",
          "Structure/Roads, Highways, or Transport",
          "Structure/Transit Station",
          "Structure/Airport",
          "Structure/Military",
          "Land Vehicle",
          "Land Vehicle/Car",
          "Land Vehicle/Truck",
          "Land Vehicle/Armored",
          "Land Vehicle/Train",
          "Land Vehicle/Bus",
          "Aircraft",
          "Aircraft/Fighter",
          "Aircraft/Bomber",
          "Aircraft/Helicopter",
          "Aircraft/Drone",
          "Sea Vehicle",
          "Sea Vehicle/Boat",
          "Sea Vehicle/Warship",
          "Sea Vehicle/Aircraft Carrier",
          "Injury",
          "Injury/Civilian",
          "Injury/Combatant",
          "Death",
          "Death/Civilian",
          "Death/Combatant"
        ],
        label: "Impact",
        description: "What is damaged, harmed, or lost in this incident?",
        pane: :attributes,
        required: false,
        name: :impact,
        deprecated: true
      },
      %Attribute{
        schema_field: :attr_equipment,
        type: :multi_select,
        # Set in ATTRIBUTE_OPTIONS environment variable to override
        options: [
          "Small Arm",
          "Munition",
          "Munition/Cluster",
          "Munition/Chemical",
          "Munition/Thermobaric",
          "Munition/Incendiary",
          "Non-Lethal Weapon",
          "Non-Lethal Weapon/Tear Gas",
          "Non-Lethal Weapon/Rubber Bullet",
          "Land Mine",
          "Launch System",
          "Launch System/Artillery",
          "Launch System/Self-Propelled",
          "Launch System/Multiple Launch Rocket System",
          "Land Vehicle",
          "Land Vehicle/Car",
          "Land Vehicle/Armored",
          "Aircraft",
          "Aircraft/Fighter",
          "Aircraft/Bomber",
          "Aircraft/Helicopter",
          "Aircraft/Drone",
          "Sea Vehicle",
          "Sea Vehicle/Small Boat",
          "Sea Vehicle/Ship",
          "Sea Vehicle/Aircraft Carrier"
        ],
        label: "Equipment Used",
        description:
          "What equipment — weapon, military infrastructure, etc. — is used in the incident?",
        pane: :attributes,
        required: false,
        name: :equipment,
        deprecated: true
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
          "For incidents that span multiple locations (e.g., movement down a street or a fire), choose a representative verifiable location.",
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
        schema_field: :attr_restrictions,
        type: :multi_select,
        label: "Restrictions",
        pane: :metadata,
        required: false,
        name: :restrictions,
        # NOTE: Editing these values also requires editing the perm checks in `media.ex`
        options: ["Frozen", "Hidden"],
        is_restricted: true
      },
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
      }
    ]

    core_attrs ++ project_attrs ++ secondary_attrs
  end

  @doc """
  Get all the active, non-deprecated attributes.
  """
  def active_attributes(opts \\ []) do
    attributes(opts) |> Enum.filter(&(&1.deprecated != true))
  end

  @doc """
  Get the names of the attributes that are available for the given media. Both nil and the empty list count as unset.

  If the :pane option is given, only attributes in that pane will be returned. If include_deprecated_attributes is true, deprecated attributes will be included.
  """
  def set_for_media(media, opts \\ []) do
    pane = Keyword.get(opts, :pane)

    Enum.filter(attributes(opts), fn attr ->
      val = Material.get_attribute_value(media, attr)

      val != nil && val != [] && val != %{"day" => "", "month" => "", "year" => ""} &&
        (pane == nil || attr.pane == pane) &&
        (attr.deprecated != true || Keyword.get(opts, :include_deprecated_attributes, false))
    end)
  end

  @doc """
  Get the names of the attributes that are not available for the given media. Both nil and the empty list count as unset.

  If the :pane option is given, only attributes in that pane will be returned.
  """
  def unset_for_media(media, opts \\ []) do
    pane = Keyword.get(opts, :pane)
    set = set_for_media(media, opts)

    attributes(opts)
    |> Enum.filter(&(!Enum.member?(set, &1)))
    |> Enum.filter(&(&1.deprecated != true))
    |> Enum.filter(&(pane == nil || &1.pane == pane))
  end

  @doc """
  Get the names of all attributes, optionally including deprecated ones.

  If the :include_renamed_attributes option is true, renamed attributes will be included.
  If the :include_deprecated_attributes option is true, deprecated attributes will be included.
  """
  def attribute_names(opts \\ []) do
    include_deprecated_attributes = Keyword.get(opts, :include_deprecated_attributes, false)
    include_renamed_attributes = Keyword.get(opts, :include_renamed_attributes, false)

    (attributes(opts)
     |> Enum.filter(&(&1.deprecated != true or include_deprecated_attributes))
     |> Enum.map(& &1.name)) ++
      if include_renamed_attributes, do: Map.keys(renamed_attributes()), else: []
  end

  @doc """
  Get an attribute by its name. Will check whether the attribute has been renamed.
  """
  def get_attribute(name_or_id, opts \\ []) do
    # Some attributes have been renamed; this allows us to keep updates
    # that reference the old name working.

    real_name =
      if is_atom(name_or_id) do
        case renamed_attributes() do
          %{^name_or_id => new_name} -> new_name
          _ -> name_or_id
        end
        |> to_string()
      else
        name_or_id
      end

    value = Enum.find(attributes(opts), &(&1.name |> to_string() == real_name))

    case value do
      nil ->
        nil

      %Attribute{} = attr ->
        project = Keyword.get(opts, :project)
        projects = Keyword.get(opts, :projects, if(is_nil(project), do: [], else: [project]))

        if not Enum.empty?(projects) and allow_user_defined_options(attr) and
             attr.type == :multi_select do
          Map.put(
            attr,
            :options,
            Material.get_values_of_attribute_cached(attr, projects: projects)
          )
        else
          attr
        end
    end
  end

  @doc """
  Get an attribute by its schema field name.
  """
  def get_attribute_by_schema_field(name, opts \\ []) do
    name = name |> to_string()
    Enum.find(attributes(opts), &(&1.schema_field |> to_string() == name))
  end

  @doc """
  Create a changeset for the media from the given attribute. Works on both core and custom attributes. If the attribute is a custom/project attribute, the project_attribute option must be given.

  Options:
    * :user - the user making the change (default: nil)
    * :verify_change_exists - whether to verify that the change exists (default: true)
    * :changeset - an existing changeset to add to (default: nil)
    * :project_attribute - the project attribute to use (default: nil) (required for project attributes)
    * :allow_invalid_selects - whether to allow invalid values in selects (default: false)
  """
  def changeset(
        %Media{} = media,
        %Attribute{} = attribute,
        attrs \\ %{},
        opts \\ []
      ) do
    user = Keyword.get(opts, :user)
    verify_change_exists = Keyword.get(opts, :verify_change_exists, true)
    changeset = Keyword.get(opts, :changeset)

    (changeset || media)
    |> cast(%{}, [])
    |> populate_virtual_data(attribute)
    |> cast_attribute(attribute, attrs)
    |> validate_attribute(attribute, media, opts)
    |> cast_and_validate_virtual_explanation(attrs, attribute)
    |> update_from_virtual_data(attribute)
    |> verify_user_can_edit(attribute, user, media)
    |> then(fn c ->
      if verify_change_exists, do: verify_change_exists(c, [attribute]), else: c
    end)
  end

  @doc """
  Create a changeset for the media from the given attributes.

  Options:
    * :user - the user making the change (default: nil)
    * :verify_change_exists - whether to verify that the change exists (default: true)
    * :changeset - an existing changeset to add to (default: nil)
  """
  def combined_changeset(
        %Media{} = media,
        attributes,
        attrs \\ %{},
        opts \\ []
      ) do
    user = Keyword.get(opts, :user)
    verify_change_exists = Keyword.get(opts, :verify_change_exists, true)
    changeset = Keyword.get(opts, :changeset)

    # Now, we need to inject the not-provided project attributes into the changeset.
    # When we cast an embedded field, we need to include all the values — but of course
    # we don't want the caller to have to do that. So we hide that complexity here.

    project_attribute_ids_in_changeset =
      attributes
      |> Enum.filter(&(&1.schema_field == :project_attributes))
      |> Enum.map(& &1.name)
      |> Enum.uniq()

    provided_project_attribute_values = Map.get(attrs, "project_attributes", %{})

    provided_project_attribute_values =
      Map.values(provided_project_attribute_values)
      |> Enum.map(&{&1["id"], &1["value"]})
      |> Map.new()

    existing_project_attribute_ids =
      media.project_attributes
      |> Enum.map(& &1.id)

    # Inject values for attributes that are not included in the changeset.
    # Add in any attributes that are not in `media.project_attributes`, but are provided in the changeset.
    synthetic_project_attributes_attrs =
      ((media.project_attributes
        |> Enum.map(
          &%{
            "id" => &1.id,
            "value" => Map.get(provided_project_attribute_values, &1.id, &1.value),
            "project_id" => &1.project_id
          }
        )) ++
         (attributes
          |> Enum.filter(&(&1.schema_field == :project_attributes))
          |> Enum.map(& &1.name)
          |> Enum.reject(&Enum.member?(existing_project_attribute_ids, &1))
          |> Enum.map(
            &%{
              "id" => &1,
              "value" => Map.get(provided_project_attribute_values, &1),
              "project_id" => media.project_id
            }
          )))
      |> Enum.with_index()
      |> Enum.map(fn {val, index} -> {to_string(index), val} end)
      |> Map.new()

    # If the map is using atom keys, set :project_attributes to the synthetic map; otherwise, use a string key.
    attrs =
      if Map.keys(attrs) |> Enum.any?(fn k -> is_atom(k) end) do
        Map.put(attrs, :project_attributes, synthetic_project_attributes_attrs)
      else
        Map.put(attrs, "project_attributes", synthetic_project_attributes_attrs)
      end

    cast_embedded_project_attributes = fn cs, subattrs ->
      attr_id = Map.get(subattrs, "id")
      attr = Enum.find(attributes, &(&1.name == attr_id))

      if attr == nil do
        cs
        # Do not modify -- just turn it into a changeset. This attribute is not provided, so we don't want to modify it.
        |> cast(%{}, [])
      else
        changeset(
          media,
          attr |> Map.put(:schema_field, :value),
          subattrs,
          Keyword.put(
            opts,
            :changeset,
            cs
            |> cast(%{}, [])
            |> put_change(:id, attr.name)
            |> put_change(:project_id, media.project_id)
          )
        )
      end
    end

    # Now it's time to start updating the media.
    cs = (changeset || media) |> cast(%{}, [])

    # Check if an embedded attribute value already exists for the given project and attribute.
    # If so, we update it. If not, we create a new one.
    cs =
      Enum.reduce(
        Enum.filter(attributes, &(&1.schema_field == :project_attributes)),
        cs,
        fn attribute, cs ->
          existing_attribute_value =
            cs
            |> get_field(:project_attributes)
            |> Enum.find(fn attribute_value ->
              attribute_value.id == attribute.name
            end)

          case existing_attribute_value do
            nil ->
              cs
              |> Ecto.Changeset.put_embed(
                :project_attributes,
                Ecto.Changeset.get_field(cs, :project_attributes) ++
                  [
                    %{
                      project_id: get_field(cs, :project_id),
                      id: attribute.name,
                      value: nil
                    }
                  ]
              )

            _ ->
              cs
          end
        end
      )

    # Cast the embedded attributes.
    cs =
      cs
      |> cast(attrs, [])
      |> cast_embed(:project_attributes, with: cast_embedded_project_attributes)

    # Cast the core attributes.
    core_attributes = Enum.filter(attributes, &(&1.schema_field != :project_attributes))

    cs =
      Enum.reduce(core_attributes, cs, fn elem, acc ->
        changeset(media, elem, attrs,
          user: user,
          verify_change_exists: false,
          changeset: acc,
          project_attribute_ids_in_changeset: project_attribute_ids_in_changeset
        )
      end)

    # Finally, verify that there is indeed a change, if a change is required.
    cs = if verify_change_exists, do: verify_change_exists(cs, attributes), else: cs

    cs
  end

  @doc """
  Checks whether the given user can edit the given attribute.
  """
  def verify_user_can_edit(changeset, attribute, user, media) do
    if is_nil(user) || Permissions.can_edit_media?(user, media, attribute) do
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
    # Populates the virtual data for the given attribute. Specifically, it:
    # * Sets the location field to a string representation of the location.

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
    # Updates the data in the changeset for the given attribute from the virtual data. Specifically, it:
    # * Sets the location field by parsing the string representation of the location.

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

  defp cast_attribute(media_or_changeset, %Attribute{} = attribute, attrs) do
    # Casts the given attribute in the Media changeset from the given attrs.

    if attribute.deprecated == true do
      raise "cannot cast deprecated attribute"
    end

    media_or_changeset
    # Explanation is a virtual field! We cast here so we can validate.
    # TODO: Is there an idiomatic way to clean this up?
    |> cast(attrs, [:explanation])
    |> then(fn changeset ->
      cond do
        # TODO: streamline location logic; this is janky
        attribute.type == :location ->
          changeset
          |> cast(attrs, [:location])

        true ->
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
    # TODO: Remove this -- it's a temporary hack to allow us to add options to attributes without
    # having to deploy code.
    extra = Jason.decode!(System.get_env("ATTRIBUTE_OPTIONS", "{}"))

    Map.get(extra, name |> to_string(), [])
  end

  @doc """
  Get the options for the provided attribute. If the attribute has custom options, those are provided.
  If the attribute allows user-defined options, those are provided. If the attribute has a "none" option,
  that is provided. If the attribute is a select or multi-select, the current values are included (provided `current_val`
  is given).
  """
  def options(%Attribute{} = attribute, current_val \\ nil) do
    options =
      case get_custom_attribute_options(attribute.name) do
        [] -> attribute.options || []
        values -> values
      end

    options =
      if attribute.add_none do
        [attribute.add_none] ++ options
      else
        options
      end

    case current_val do
      nil -> options
      l when is_list(l) -> options ++ l
      v -> options ++ [v]
    end
  end

  @doc """
  Validates the given attribute in the given changeset.

  Options:
  * `:user` - the user performing the action.
  * `:required` - whether the attribute is required. Defaults to true.
  * `:allow_invalid_selects` - whether to allow invalid options in multi- and single-selects. Defaults to false.
  """
  def validate_attribute(changeset, %Attribute{} = attribute, %Media{} = media, opts \\ []) do
    user = Keyword.get(opts, :user, nil)
    required = Keyword.get(opts, :required, true)

    validations =
      case attribute.type do
        :multi_select ->
          if Attribute.allow_user_defined_options(attribute) == true do
            # If `allow_user_defined_options` is unset or false, verify that the
            # values are a subset of the options.
            changeset
          else
            changeset
            |> validate_change(attribute.schema_field, fn _, vals ->
              # Equivalent to validate_subset; we use our own because we want to operate on all
              # enumerable types, not just {:array, _}.
              if Enum.any?(vals, fn val -> not Enum.member?(options(attribute), val) end) and
                   not Keyword.get(opts, :allow_invalid_selects, false) do
                invalid = Enum.reject(vals, fn val -> Enum.member?(options(attribute), val) end)

                [
                  {attribute.schema_field,
                   "Includes invalid value(s): #{Enum.join(invalid, ", ")}. Valid values are: #{Enum.join(options(attribute), ", ")}"}
                ]
              else
                []
              end
            end)
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
          |> validate_privileged_values(attribute, user, media)

        :select ->
          changeset
          |> then(fn changeset ->
            if Keyword.get(opts, :allow_invalid_selects, false) do
              changeset
            else
              changeset
              |> validate_inclusion(attribute.schema_field, options(attribute),
                message:
                  "Includes an invalid value. Valid values are: " <>
                    Enum.join(options(attribute), ", ")
              )
            end
          end)
          |> validate_privileged_values(attribute, user, media)

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

    if attribute.required and required do
      custom |> validate_required([attribute.schema_field])
    else
      custom
    end
  end

  defp cast_and_validate_virtual_explanation(changeset, params, attribute) do
    # Cast and validate the `explanation` field, which is virtual and not part of the schema.
    # Instead, it's passed to the `update` model. Some attributes require an explanation,
    # and some don't -- that is validated by this function.

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

  defp validate_privileged_values(
         changeset,
         %Attribute{} = attribute,
         %User{} = user,
         %Media{} = media
       )
       when is_list(attribute.privileged_values) do
    # Some attributes have values that can only be set by privileged users. This function
    # validates that the values are not set by non-privileged users.

    if Permissions.can_set_restricted_attribute_values?(user, media, attribute) do
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
              "Only project managers and owners can set the following values: " <>
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
              "Only project managers and owners can set the value to '" <> v <> "'"
            )
          else
            changeset
          end
      end
    end
  end

  defp validate_privileged_values(changeset, _attribute, _user, _media) do
    # When attribute and user aren't provided, or there are no privileged values,
    # then there is nothing to validate.

    changeset
  end

  defp verify_change_exists(changeset, attributes) do
    # Verify that at least one of the given attributes has changed. This is used
    # to ensure that users don't post updates that don't actually change anything.

    if not Enum.any?(attributes, &Map.has_key?(changeset.changes, &1.schema_field)) do
      changeset
      |> add_error(hd(attributes).schema_field, "A change is required to post an update.")
    else
      changeset
    end
  end

  @doc """
  Get the color (in "a17t" terms) for the given attribute value.
  """
  def attr_color(name, value) do
    case name do
      :sensitive ->
        case value do
          ["Not Sensitive"] -> "~neutral"
          _ -> "~critical"
        end

      :status ->
        case value do
          "Unclaimed" -> "~positive"
          "In Progress" -> "~purple"
          "Cancelled" -> "~neutral"
          "Ready for Review" -> "~cyan"
          "Completed" -> "~urge"
          "Needs Upload" -> "~neutral"
          _ -> "~warning"
        end

      _ ->
        "~neutral"
    end
  end

  @doc """
  Checks whether the attribute allows user-defined options (i.e., custom new options).
  """
  def allow_user_defined_options(%Attribute{allow_user_defined_options: true}) do
    true
  end

  def allow_user_defined_options(%Attribute{}) do
    false
  end

  @doc """
  Checks whether the attribute requires special privileges to edit.
  """
  def requires_privileges_to_edit(%Attribute{} = attr) do
    attr.is_restricted
  end

  @doc """
  Get the child attributes of the given parent attribute. Children are used to combine multiple
  distinct attributes into a single editing experience (e.g., geolocation and geolocation accuracy).
  """
  def get_children(parent_name, opts \\ []) do
    attributes(opts) |> Enum.filter(&(&1.parent == parent_name))
  end
end
