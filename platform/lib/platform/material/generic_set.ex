defmodule Platform.Material.GenericSet do
  @moduledoc """
  A generic replacement for Ecto.Changeset that can be used with string keys.
  Implementation references https://github.com/phoenixframework/phoenix_ecto/blob/223bdb6aa38831817602a2a5a844f1b5494955df/lib/phoenix_ecto/html.ex#L4
  """
  alias __MODULE__

  defstruct changes: %{},
            errors: [],
            data: %{},
            valid?: true,
            params: nil

  def add_error(%GenericSet{errors: errors} = gset, key, message, keys \\ [])
      when is_binary(message) do
    %{gset | errors: [{key, {message, keys}} | errors], valid?: false}
  end

  defimpl Phoenix.HTML.FormData do
    @impl true
    def to_form(gset, opts) do
      %{params: params, data: data} = gset
      {name, opts} = Keyword.pop(opts, :as)

      name = to_string(name || form_for_name(data))
      id = Keyword.get(opts, :id) || name

      %Phoenix.HTML.Form{
        source: gset,
        impl: __MODULE__,
        id: id,
        name: name,
        errors: form_for_errors(gset),
        data: data,
        params: params || %{},
        hidden: form_for_hidden(data),
        options: Keyword.put_new(opts, :method, form_for_method(data))
      }
    end

    @impl true
    def input_value(%{changes: changes, data: data}, %{params: params}, field) do
      case changes do
        %{^field => value} ->
          value

        %{} ->
          case params do
            %{^field => value} -> value
            %{} -> Map.get(data, field)
          end
      end
    end

    @impl true
    def input_value(%{action: parent_action} = source, form, field, opts) do
      if Keyword.has_key?(opts, :default) do
        raise ArgumentError,
              ":default is not supported on inputs_for with changesets. " <>
                "The default value must be set in the changeset data"
      end

      {prepend, opts} = Keyword.pop(opts, :prepend, [])
      {append, opts} = Keyword.pop(opts, :append, [])
      {name, opts} = Keyword.pop(opts, :as)
      {id, opts} = Keyword.pop(opts, :id)
      {default, opts} = Keyword.pop(opts, :default, %{})

      id = to_string(id || form.id <> "_#{field}")
      name = to_string(name || form.name <> "[#{field}]")
      params = Map.get(form.params, field)

      cond do
        is_map(default) ->
          [
            %Phoenix.HTML.Form{
              source: source,
              impl: __MODULE__,
              id: id,
              name: name,
              data: default,
              params: params || %{},
              options: opts
            }
          ]

        is_list(default) ->
          entries =
            if params do
              params
              |> Enum.sort_by(&elem(&1, 0))
              |> Enum.map(&{nil, elem(&1, 1)})
            else
              Enum.map(prepend ++ default ++ append, &{&1, %{}})
            end

          for {{data, params}, index} <- Enum.with_index(entries) do
            index_string = Integer.to_string(index)

            %Phoenix.HTML.Form{
              source: source,
              impl: __MODULE__,
              index: index,
              id: id <> "_" <> index_string,
              name: name <> "[" <> index_string <> "]",
              data: data,
              params: params,
              options: opts
            }
          end
      end
    end

    @impl true
    def input_type(%{types: types}, _, field) do
      type = Map.get(types, field, :string)
      type = if Ecto.Type.primitive?(type), do: type, else: type.type

      case type do
        :integer -> :number_input
        :boolean -> :checkbox
        :date -> :date_select
        :time -> :time_select
        :utc_datetime -> :datetime_select
        :naive_datetime -> :datetime_select
        _ -> :text_input
      end
    end

    defp form_for_name(%{__struct__: module}) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
    end

    defp form_for_name(_) do
      raise ArgumentError,
            "cannot generate name for changeset where the data is not backed by a struct. " <>
              "You must either pass the :as option to form/form_for or use a struct-based changeset"
    end

    defp form_for_hidden(%{__struct__: module} = data) do
      module.__schema__(:primary_key)
    rescue
      _ -> []
    else
      keys -> for k <- keys, v = Map.fetch!(data, k), do: {k, v}
    end

    defp form_for_hidden(_), do: []

    defp form_for_method(%{__meta__: %{state: :loaded}}), do: "put"
    defp form_for_method(_), do: "post"

    defp form_for_errors(%{action: nil}), do: []
    defp form_for_errors(%{action: :ignore}), do: []
    defp form_for_errors(%{errors: errors}), do: errors
  end
end
