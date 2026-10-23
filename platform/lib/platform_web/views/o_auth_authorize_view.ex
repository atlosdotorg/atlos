defmodule PlatformWeb.OAuthAuthorizeView do
  use PlatformWeb, :view

  def redirect_host(redirect_uri) do
    case URI.parse(redirect_uri) do
      %URI{host: host} when host not in [nil, ""] -> host
      %URI{scheme: scheme} -> "#{scheme}://"
    end
  end

  @access_levels [
    %{
      value: "edit",
      scopes: ["read", "comment", "edit"],
      label: "Read, comment, and edit",
      description:
        "view incidents, post comments, add source material, create incidents, and change attributes"
    },
    %{
      value: "comment",
      scopes: ["read", "comment"],
      label: "Read and comment",
      description: "view incidents and post comments"
    },
    %{
      value: "read",
      scopes: ["read"],
      label: "Read only",
      description: "view incidents, their activity, and source material"
    }
  ]

  @doc """
  The access levels to offer: those whose scopes were all requested and are
  allowed by at least one of the user's roles.
  """
  def access_levels(offered_scopes),
    do:
      Enum.filter(@access_levels, fn level -> Enum.all?(level.scopes, &(&1 in offered_scopes)) end)

  @doc """
  The access level selected by default: the most access on offer.
  """
  def default_access(offered_scopes), do: hd(access_levels(offered_scopes)).value

  def role_name(role), do: role |> to_string() |> String.replace("_", " ") |> String.capitalize()

  @doc """
  What a client given `scopes` can do in a project where the user has `role`.
  """
  def permissions_label(scopes, role) do
    case Platform.OAuth.scopes_in_project(scopes, role) do
      ["read", "comment", "edit"] -> "Read, comment, edit"
      ["read", "comment"] -> "Read, comment"
      ["read"] -> "Read only"
      _ -> "No access"
    end
  end
end
