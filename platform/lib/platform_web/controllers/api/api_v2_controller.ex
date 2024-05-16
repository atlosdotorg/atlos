defmodule PlatformWeb.APIV2Controller do
  alias Platform.Projects
  alias Platform.Material.Attribute
  alias Platform.Permissions
  alias Platform.Updates
  alias Platform.Auditor
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

  def media_versions(conn, params) do
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

  def media_version(conn, params) do
    project_id = conn.assigns.token.project_id
    media_version = Material.get_media_version(params["id"])

    cond do
      is_nil(media_version) or media_version.media.project_id != project_id ->
        json(conn |> put_status(401), %{error: "media version not found or unauthorized"})

      true ->
        json(conn, %{success: true, result: media_version})
    end
  end

  def create_media_version(conn, params) do
    media_id = params["slug"]
    url = params["url"]
    should_archive = params["archive"] == "true"

    media = Material.get_full_media_by_slug(media_id)

    cond do
      is_nil(media) or not Permissions.can_api_token_edit_media?(conn.assigns.token, media) ->
        json(conn |> put_status(401), %{error: "incident not found or unauthorized"})

      true ->
        {:ok, version} =
          Material.create_media_version_audited(media, conn.assigns.token, %{
            upload_type: if(should_archive, do: :direct, else: :user_provided),
            status: :pending,
            source_url: url,
            media_id: media_id
          })

        Platform.Material.archive_media_version(version)

        json(conn, %{success: true, result: version})
    end
  end

  def set_media_version_metadata(conn, params) do
    version_id = params["id"]
    namespace = params["namespace"]
    metadata = params["metadata"]

    media_version = Material.get_media_version(version_id)

    cond do
      is_nil(media_version) or
          not Permissions.can_api_token_edit_media?(conn.assigns.token, media_version.media) ->
        json(conn |> put_status(401), %{error: "media version not found or unauthorized"})

      true ->
        {:ok, version} =
          Platform.Repo.transaction(fn ->
            new_metadata = Map.put(media_version.metadata || %{}, namespace, metadata)

            {:ok, version} =
              Material.update_media_version(media_version, %{"metadata" => new_metadata})

            version
          end)

        json(conn, %{success: true, result: version})
    end
  end

  def upload_media_version_file(conn, params) do
    version_id = params["id"]
    media_version = Material.get_media_version(version_id)

    cond do
      is_nil(media_version) or
          not Permissions.can_api_token_edit_media?(conn.assigns.token, media_version.media) ->
        json(conn |> put_status(401), %{error: "media version not found or unauthorized"})

      true ->
        title = params["title"]

        case params["file"] do
          %Plug.Upload{} = file ->
            # First, upload the artifact to the storage backend.
            id = Ecto.UUID.generate()

            # Give the file an appropriate file extension and rename the file such
            # that it has the extension (important for file type detection later)
            local_path = file.path
            ext = Path.extname(file.filename)
            new_loc = "#{local_path}#{ext}"
            File.rename!(local_path, new_loc)

            {:ok, remote_path} =
              if System.get_env("MIX_ENV") != "test" do
                Platform.Uploads.MediaVersionArtifact.store({new_loc, %{id: id}})
              else
                {:ok, "test"}
              end

            # Then, create the artifact record in the database.
            artifact = %Platform.Material.MediaVersion.MediaVersionArtifact{
              id: id,
              file_location: remote_path,
              file_hash_sha256: Platform.Utils.hash_sha256(new_loc),
              file_size: File.stat!(new_loc).size,
              mime_type: MIME.from_path(new_loc),
              type: :upload,
              uploading_token_id: conn.assigns.token.id,
              title: title
            }

            {:ok, new_version} =
              Platform.Repo.transaction(fn ->
                # Get an up to date copy of the media version to avoid race conditions
                media_version = Material.get_media_version(version_id)

                {:ok, new_version} =
                  Material.add_artifact_to_media_version(media_version, artifact)

                new_version
              end)

            # Schedule the media version for additional processing
            Material.rearchive_media_version(new_version)

            Auditor.log(
              :media_version_uploaded,
              %{"params" => params, "version" => new_version, "new_media_version_id" => id},
              conn
            )

            json(conn, %{success: true, result: new_version})

          _ ->
            json(conn |> put_status(401), %{error: "valid file not provided"})
        end
    end
  end

  def incidents(conn, params) do
    project_id = conn.assigns.token.project_id

    base_query =
      from(m in Material.Media,
        where: m.project_id == ^project_id
      )

    search_changeset = Material.MediaSearch.changeset(params)

    {query, pagination_options} =
      Material.MediaSearch.search_query(base_query, search_changeset)

    pagination_api(conn, params, fn opts ->
      Material.query_media_paginated(
        query,
        Keyword.merge(pagination_options, opts)
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

  def get_updates(conn, params) do
    project_id = conn.assigns.token.project_id

    media_slug = params["slug"]

    media =
      if media_slug do
        Material.get_full_media_by_slug(media_slug)
      else
        nil
      end

    cond do
      (not is_nil(media_slug) and is_nil(media)) or
          (not is_nil(media) and media.project_id != project_id) ->
        conn |> put_status(401) |> json(%{error: "media not found"})

      not Permissions.can_api_token_read_updates?(conn.assigns.token) ->
        conn |> put_status(401) |> json(%{error: "api token not authorized to read updates"})

      true ->
        pagination_api(conn, params, fn opts ->
          Updates.query_updates_paginated(
            from(u in Updates.Update,
              join: m in assoc(u, :media),
              where: m.project_id == ^project_id,
              order_by: [desc: u.inserted_at],
              preload: [:user, media: m]
            )
            |> then(fn q ->
              if media do
                where(q, [u], u.media_id == ^media.id)
              else
                q
              end
            end),
            opts
          )
        end)
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
