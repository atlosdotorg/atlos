defmodule PlatformWeb.APIV2Controller do
  alias Platform.Projects
  alias Platform.Material.Attribute
  alias Platform.Permissions
  use PlatformWeb, :controller
  import Ecto.Query

  alias Platform.Material

  defp sign_value(value, api_token) do
    if is_nil(value) do
      nil
    else
      Phoenix.Token.sign(PlatformWeb.Endpoint, api_token, Jason.encode!(value))
    end
  end

  defp extract_value(value, api_token) do
    with {:ok, encoded_value} <-
           Phoenix.Token.verify(PlatformWeb.Endpoint, api_token, value, max_age: 86400),
         {:ok, decoded_value} <- Jason.decode(encoded_value) do
      {:ok, decoded_value}
    else
      _ -> {:error, "unable to verify or parse pagination information"}
    end
  end

  defp pagination_api(conn, params, pagination_function) do
    token = conn.assigns.token.value
    cursor_unverified = Map.get(params, "cursor")

    cursor_result =
      if is_nil(cursor_unverified) do
        {:ok, nil}
      else
        extract_value(cursor_unverified, token)
      end

    with {:ok, page} <- cursor_result do
      results =
        pagination_function.(
          sort: "modified_desc",
          after: page
        )

      json(conn, %{
        results: results.entries,
        next:
          if(is_nil(results.metadata.after),
            do: nil,
            else: sign_value(results.metadata.after, token)
          ),
        previous:
          if(is_nil(results.metadata.before),
            do: nil,
            else: sign_value(results.metadata.before, token)
          )
      })
    else
      {:error, message} -> json(conn, %{error: message})
    end
  end

  def source_material(conn, params) do
    project_id = conn.assigns.token.project_id

    pagination_api(conn, params, fn opts ->
      Material.query_media_versions_paginated(
        from(m in Material.MediaVersion,
          join: incident in assoc(m, :media),
          where: incident.project_id == ^project_id,
          order_by: [desc: m.inserted_at]
        ),
        opts
      )
    end)
  end

  def incidents(conn, params) do
    project_id = conn.assigns.token.project_id

    pagination_api(conn, params, fn opts ->
      Material.query_media_paginated(
        from(m in Material.Media,
          where: m.project_id == ^project_id,
          order_by: [desc: m.inserted_at]
        ),
        opts
      )
    end)
  end

  def add_comment(conn, params) do
    project_id = conn.assigns.token.project_id
    message = params["message"]

    media = Material.get_full_media_by_slug(params["slug"])

    cond do
      is_nil(media) or media.project_id != project_id ->
        json(conn |> put_status(401), %{error: "incident not found"})

      not Permissions.can_api_token_post_comment?(conn.assigns.token, media) ->
        json(conn |> put_status(401), %{error: "api token not authorized to post comment"})

      is_nil(message) ->
        json(conn |> put_status(401), %{error: "message not provided"})

      true ->
        result = Platform.Updates.post_comment_from_api_token(media, conn.assigns.token, message)

        case result do
          {:ok, _} ->
            json(conn, %{success: true})

          {:error, changeset} ->
            json(conn |> put_status(401), %{error: render_changeset_errors(changeset)})
        end
    end
  end

  def update(conn, params) do
    project_id = conn.assigns.token.project_id
    project = Projects.get_project!(project_id)

    # ok if nil
    message = params["message"]

    attribute = params["attribute"] |> Attribute.get_attribute(project: project)
    value = params["value"]
    media = Material.get_full_media_by_slug(params["slug"])

    cond do
      is_nil(value) ->
        json(conn |> put_status(401), %{error: "value not provided"})

      is_nil(media) or media.project_id != project_id ->
        json(conn |> put_status(401), %{error: "incident not found"})

      not Permissions.can_api_token_edit_media?(conn.assigns.token, media) ->
        json(conn |> put_status(401), %{error: "api token not authorized to edit"})

      is_nil(attribute) ->
        json(conn |> put_status(401), %{error: "attribute not found"})

      true ->
        result =
          Material.update_media_attributes_audited(
            media,
            [attribute],
            Material.generate_attribute_change_params(attribute, value, project, %{
              "explanation" => message
            }),
            api_token: conn.assigns.token
          )

        case result do
          {:ok, _} ->
            json(conn, %{success: true})

          {:error, changeset} ->
            json(conn |> put_status(401), %{error: render_changeset_errors(changeset)})
        end
    end
  end

  defp render_changeset_errors(changeset) do
    Enum.map(changeset.errors, fn {field, detail} ->
      {field, render_detail(detail)}
    end)
    |> Enum.into(%{})
  end

  defp render_detail({message, values}) do
    Enum.reduce(values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end)
  end

  defp render_detail(message) do
    message
  end
end
