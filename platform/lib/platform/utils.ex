defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """
  import Ecto.Query, warn: false

  @tag_regex ~r/((?:\[\[))(@([A-Za-z0-9_]+)(?:\]\]))/
  @identifier_regex ~r/(?:\[\[)((?:[A-Z0-9]{1,5}-)?[A-Z0-9]{6})(?:\]\])/
  @identifier_regex_with_project_and_no_tags ~r/((?:[A-Z0-9]{1,5}-)([A-Z0-9]{6}))/

  def get_tag_regex(), do: @tag_regex
  def get_identifier_regex(), do: @identifier_regex

  def generate_media_slug() do
    slug = for _ <- 1..6, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>

    if !is_nil(Platform.Material.get_full_media_by_slug(slug)) do
      generate_media_slug()
    else
      slug
    end
  end

  def generate_random_sequence(length) do
    for _ <- 1..length, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
  end

  def generate_secure_code() do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  def make_keys_strings(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  def slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-zA-Z0-9 &]/, "")
    |> String.replace("&", "and")
    |> String.split()
    |> Enum.join("-")
  end

  def truncate(str, length \\ 30) do
    if String.length(str) > length do
      "#{String.slice(str, 0, length - 3) |> String.trim()}..."
    else
      str
    end
  end

  def check_captcha(params) do
    token = Map.get(params, "h-captcha-response")

    if System.get_env("ENABLE_CAPTCHAS", "false") == "false" do
      true
    else
      if is_nil(token) or String.length(token) == 0 do
        false
      else
        {:ok, _status, _headers, body} =
          :hackney.post(
            "https://hcaptcha.com/siteverify",
            [{"Content-Type", "application/x-www-form-urlencoded"}],
            # Is this interpolation secure?
            "response=#{token}&secret=#{System.get_env("HCAPTCHA_SECRET")}",
            [:with_body]
          )

        body |> Jason.decode!() |> Map.get("success")
      end
    end
  end

  def render_markdown(markdown) do
    # Safe markdown rendering. No images or headers.

    # First, strip images and turn them into links. Primitive.
    markdown = Regex.replace(~r"!*\[", markdown, "[")

    # Second, link ATL identifiers.
    markdown = Regex.replace(@identifier_regex, markdown, " [\\1](/incidents/\\1)")

    # Third, turn @'s into links.
    markdown = Regex.replace(@tag_regex, markdown, " [@\\3](/profile/\\3)")

    # Setup to open external links in a new tab + add nofollow/noopener
    add_target = fn node ->
      if not is_nil(Earmark.AstTools.find_att_in_node(node, "href", "")),
        do: Earmark.AstTools.merge_atts_in_node(node, target: "_blank", rel: "nofollow noopener"),
        else: node
    end

    detect_tags = fn node ->
      link = Earmark.AstTools.find_att_in_node(node, "href", "")

      if not is_nil(link) and
           (String.starts_with?(link, "/profile/") or String.starts_with?(link, "/incidents/")),
         do:
           Earmark.AstTools.merge_atts_in_node(node,
             "internal-tag": "true",
             "data-tag-target": String.split(link, "/") |> List.last()
           ),
         else: node
    end

    options = [registered_processors: [{"a", add_target}, {"a", detect_tags}]]

    # Strip all tags and render markdown
    markdown = markdown |> Earmark.as_html!(options)

    # Perform another round of cleaning (images will be stripped here too)
    markdown = markdown |> HtmlSanitizeEx.Scrubber.scrub(Platform.Security.UgcSanitizer)

    markdown
  end

  def generate_qrcode(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: 264)
    |> Phoenix.HTML.raw()
  end

  def get_instance_name() do
    System.get_env("INSTANCE_NAME")
  end

  def get_instance_version() do
    System.get_env("APP_REVISION", "unknown")
  end

  def get_runtime_information() do
    region = System.get_env("FLY_REGION", "unknown")
    alloc_id = System.get_env("FLY_ALLOC_ID", "unknown")

    "allocation #{alloc_id} in region #{region}"
  end

  def text_search(search_terms, queryable, opts \\ []) do
    # First, detect if they have entered a slug with a project code into the query. If so, we add a version of the slug without the project code to the query.
    # This is to make it possible to search for "ATL-123" and get results for "123".
    # This is a bit hacky, but it works.
    search_terms = Regex.replace(@identifier_regex_with_project_and_no_tags, search_terms, "\\2")

    if Keyword.get(opts, :literal, false) do
      # Manually adding the quotes here make it possible to search for source links directly
      wrapped =
        if String.starts_with?(search_terms, "\""), do: search_terms, else: "\"#{search_terms}\""

      queryable
      |> where(
        [q],
        fragment("? @@ websearch_to_tsquery('english', ?)", q.searchable, ^wrapped)
      )
    else
      queryable
      |> where(
        [q],
        fragment("? @@ websearch_to_tsquery('english', ?)", q.searchable, ^search_terms)
      )
    end
  end
end
