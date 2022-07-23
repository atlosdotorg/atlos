defmodule PlatformWeb.APIV1Controller do
  use PlatformWeb, :controller
  require Ecto.Query

  alias Platform.Material

  defp sign_value(value, api_token) do
    if not is_nil(value) do
      Phoenix.Token.sign(PlatformWeb.Endpoint, api_token, Jason.encode!(value))
    else
      nil
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
        next: sign_value(results.metadata.after, token),
        previous: sign_value(results.metadata.before, token)
      })
    else
      {:error, message} -> json(conn, %{error: message})
    end
  end

  def media_versions(conn, params) do
    pagination_api(conn, params, fn opts ->
      Material.query_media_versions_paginated(
        Material.MediaVersion
        |> Ecto.Query.order_by(desc: :updated_at),
        opts
      )
    end)
  end

  def media(conn, params) do
    pagination_api(conn, params, fn opts ->
      Material.query_media_paginated(
        Material.Media
        |> Ecto.Query.order_by(desc: :updated_at),
        opts
      )
    end)
  end
end
