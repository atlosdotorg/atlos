defmodule PlatformWeb.OAuthAuthorizeView do
  use PlatformWeb, :view

  def redirect_host(redirect_uri) do
    case URI.parse(redirect_uri) do
      %URI{host: host} when host not in [nil, ""] -> host
      %URI{scheme: scheme} -> "#{scheme}://"
    end
  end

  @doc """
  What a connected client can do at most in a project, given the user's role.
  """
  def role_limit(role) do
    role_name = role |> to_string() |> String.capitalize()

    case Platform.OAuth.scopes_for_role(role) do
      ["read", "comment", "edit"] -> "#{role_name} · up to edit"
      ["read", "comment"] -> "#{role_name} · up to comment"
      _ -> "#{role_name} · read only"
    end
  end
end
