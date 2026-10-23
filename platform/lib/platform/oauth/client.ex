defmodule Platform.OAuth.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @browser_handled_schemes ~w(javascript data file vbscript about blob filesystem ftp ws wss mailto tel sms)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "oauth_clients" do
    field :client_id, :string
    field :client_name, :string
    field :redirect_uris, {:array, :string}, default: []

    timestamps()
  end

  @doc """
  Changeset for dynamic client registration. Redirect URIs must be HTTPS,
  loopback HTTP (for native apps, RFC 8252 section 7.3), or a private-use URI
  scheme for a native app (RFC 8252 section 7.1, e.g. `cursor://...`).
  """
  def registration_changeset(client, attrs) do
    client
    |> cast(attrs, [:client_name, :redirect_uris])
    |> update_change(:client_name, &String.trim/1)
    |> validate_required([:client_name, :redirect_uris])
    |> validate_length(:client_name, min: 1, max: 100)
    |> validate_length(:redirect_uris, min: 1, max: 10)
    |> validate_change(:redirect_uris, fn :redirect_uris, uris ->
      case Enum.reject(uris, &valid_redirect_uri?/1) do
        [] -> []
        invalid -> [redirect_uris: "invalid redirect URIs: #{Enum.join(invalid, ", ")}"]
      end
    end)
    |> put_change(:client_id, "atlos_client_" <> Platform.OAuth.random_token())
  end

  def valid_redirect_uri?(uri) when is_binary(uri) and byte_size(uri) <= 2000 do
    case URI.new(uri) do
      {:ok, %URI{scheme: "https", host: host, fragment: nil}} when host not in [nil, ""] ->
        true

      {:ok, %URI{scheme: "http", host: host, fragment: nil}} ->
        loopback_host?(host)

      {:ok, %URI{scheme: scheme, fragment: nil}} when is_binary(scheme) ->
        # Private-use schemes for native apps. RFC 8252 recommends reverse
        # domain names, but popular clients (e.g. Cursor) use plain names, so
        # instead rule out schemes that a browser would act on itself.
        String.match?(scheme, ~r/^[a-z][a-z0-9+.\-]*$/) and
          scheme not in @browser_handled_schemes

      _ ->
        false
    end
  end

  def valid_redirect_uri?(_), do: false

  def loopback_host?(host), do: host in ["localhost", "127.0.0.1", "[::1]", "::1"]

  @doc """
  Whether `requested` matches one of the client's registered redirect URIs.
  Matching is exact, except that the port of a loopback redirect URI may vary
  (RFC 8252 section 7.3), since native apps pick a free port at runtime.
  """
  def redirect_uri_allowed?(%__MODULE__{redirect_uris: registered}, requested)
      when is_binary(requested) do
    Enum.any?(registered, fn uri ->
      uri == requested or loopback_match?(uri, requested)
    end)
  end

  def redirect_uri_allowed?(_, _), do: false

  defp loopback_match?(registered, requested) do
    with {:ok, %URI{scheme: "http"} = a} <- URI.new(registered),
         {:ok, %URI{scheme: "http"} = b} <- URI.new(requested),
         true <- loopback_host?(a.host) do
      a.host == b.host and a.path == b.path and a.query == b.query and is_nil(b.fragment)
    else
      _ -> false
    end
  end
end
