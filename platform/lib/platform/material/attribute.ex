defmodule Platform.Material.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias Platform.Material.Media

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
    :description
  ]

  defp attributes() do
    [
      %Attribute{
        schema_field: :attr_sensitive,
        type: :multi_select,
        options: [
          "Not Sensitive",
          "Threatens Civilian Safety",
          "Graphic Violence",
          "Deleted by Source",
          "Deceptive or Misleading"
        ],
        label: "Sensitivity",
        min_length: 1,
        pane: :metadata,
        required: true,
        custom_validation: fn :attr_sensitive, vals ->
          if Enum.member?(vals, "Not Sensitive") && length(vals) > 1 do
            [attr_sensitive: "If the media is 'Not Sensitive,' no other options may be selected"]
          else
            []
          end
        end,
        name: :sensitive
      },
      %Attribute{
        schema_field: :description,
        type: :text,
        max_length: 240,
        min_length: 8,
        label: "Description",
        pane: :metadata,
        required: true,
        name: :description
      },
      %Attribute{
        schema_field: :attr_time_of_day,
        type: :select,
        options: ["Night", "Day"],
        label: "Time of Day",
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
    attributes() |> Enum.map(& &1.name)
  end

  def get_attribute(name) do
    hd(Enum.filter(attributes(), &(&1.name == name)))
  end

  def changeset(media, %Attribute{} = attribute, attrs \\ %{}) do
    media
    |> populate_virtual_data(attribute)
    |> cast_attribute(attribute, attrs)
    |> validate_attribute(attribute)
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

        changeset
        |> put_change(attribute.schema_field, %Geo.Point{coordinates: {lon, lat}, srid: 4326})

      _ ->
        changeset
    end
  end

  defp cast_attribute(media, %Attribute{} = attribute, attrs) do
    case attribute.type do
      :location -> media |> cast(attrs, [:latitude, :longitude])
      _ -> media |> cast(attrs, [attribute.schema_field])
    end
  end

  def validate_attribute(changeset, %Attribute{} = attribute) do
    validations =
      case attribute.type do
        :multi_select ->
          changeset
          |> validate_subset(attribute.schema_field, attribute.options)
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )

        :select ->
          changeset
          |> validate_inclusion(attribute.schema_field, attribute.options)

        :text ->
          changeset
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )

        :location ->
          changeset
          |> validate_required([:latitude, :longitude])
      end

    if attribute.custom_validation != nil do
      validations |> validate_change(attribute.schema_field, attribute.custom_validation)
    else
      validations
    end
  end
end
