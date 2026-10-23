defmodule Platform.FlexibleJSONType do
  use Ecto.Type

  def type, do: :map

  # When loading from an embed (e.g. media.project_attributes), use load/1 rather than cast/1.
  # cast/1 JSON-encodes the entire value to validate it, which is very expensive for large values
  # and unnecessary for data that came out of the database.
  def embed_as(_format), do: :dump

  # Provide custom casting rules.
  def cast(data) do
    case Jason.encode(data) do
      {:ok, _} -> {:ok, data}
      {:error, _} -> :error
    end
  end

  def load(data) do
    {:ok, data}
  end

  def dump(data) do
    case Jason.encode(data) do
      {:ok, _} -> {:ok, data}
      {:error, _} -> :error
    end
  end
end
