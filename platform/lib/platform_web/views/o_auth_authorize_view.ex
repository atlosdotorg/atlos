defmodule PlatformWeb.OAuthAuthorizeView do
  use PlatformWeb, :view

  def redirect_host(redirect_uri) do
    case URI.parse(redirect_uri) do
      %URI{host: host} when host not in [nil, ""] -> host
      %URI{scheme: scheme} -> "#{scheme}://"
    end
  end

  def role_label(role), do: role |> to_string() |> String.replace("_", " ")
end
