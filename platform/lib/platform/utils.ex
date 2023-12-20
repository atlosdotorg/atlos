defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """
  import Ecto.Query, warn: false

  @tag_regex ~r/((?:\[\[))(@([A-Za-z0-9_]+)(?:\]\]))/
  @identifier_regex ~r/(?:\[\[)((?:[A-Za-z0-9]{1,5}-)?[A-Z0-9]{6})(?:\]\])/
  @identifier_with_media_version_regex ~r/(?:\[\[)((?:[A-Za-z0-9]{1,5}-)?([A-Z0-9]{6})\/(\d+))(?:\]\])/
  @identifier_regex_with_project_and_no_tags ~r/((?:[A-Za-z0-9]{1,5}-)([A-Z0-9]{6}))/

  def get_tag_regex(), do: @tag_regex
  def get_identifier_regex(), do: @identifier_regex

  def generate_media_slug() do
    slug = for _ <- 1..6, into: "", do: <<Enum.random(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")>>

    if is_nil(Platform.Material.get_full_media_by_slug(slug)) do
      slug
    else
      generate_media_slug()
    end
  end

  def generate_random_sequence(length) do
    for _ <- 1..length, into: "", do: <<Enum.random(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")>>
  end

  def generate_secure_code() do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  def pluralize(count, singular, plural \\ nil) do
    if count == 1 do
      singular
    else
      if is_nil(plural) do
        singular <> "s"
      else
        plural
      end
    end
  end

  def migrated_attributes(media) do
    if is_nil(media.project) do
      []
    else
      project_attributes =
        media.project.attributes |> Enum.map(&Platform.Projects.ProjectAttribute.to_attribute(&1))

      deprecated_attributes =
        Platform.Material.Attribute.attributes() |> Enum.filter(&(&1.deprecated == true))

      deprecated_attributes
      |> Enum.map(fn deprecated_attribute ->
        new_attribute =
          project_attributes
          |> Enum.find(
            &(&1.label == deprecated_attribute.label && &1.type == deprecated_attribute.type)
          )

        if is_nil(new_attribute) do
          nil
        else
          {deprecated_attribute, new_attribute}
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  def hash_sha256(filepath) do
    :crypto.hash(:sha256, File.read!(filepath)) |> Base.encode16() |> String.downcase()
  end

  def format_date(value) do
    case value do
      %Date{} ->
        value |> Calendar.strftime("%d %B %Y")

      %{"day" => "", "month" => "", "year" => ""} ->
        "Unset"

      %{"day" => day, "month" => month, "year" => year} ->
        %Date{
          day: Integer.parse(day) |> elem(0),
          month: Integer.parse(month) |> elem(0),
          year: Integer.parse(year) |> elem(0)
        }
        |> Calendar.strftime("%d %B %Y")

      str when is_binary(str) ->
        str |> Date.from_iso8601() |> elem(1) |> Calendar.strftime("%d %B %Y")

      _ ->
        value
    end
  end

  def make_keys_strings(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  def is_processable_image(mime_type) do
    mime_type in ["image/jpeg", "image/png", "image/gif", "image/tiff", "image/bmp"]
  end

  def is_processable_media(mime_type) do
    is_processable_image(mime_type) or
      String.starts_with?(mime_type, "video/")
  end

  def slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-zA-Z0-9 &\.]/, "")
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

    # Preprocessing: replace single linebreaks with double linebreaks _except_ when the newline is followed by a list item or a digit (i.e. a numbered list)
    markdown = Regex.replace(~r/([^\n])(\n)(?![0-9]|\*)/, markdown, "\\1\\2\\2")

    # First, strip images and turn them into links. Primitive.
    markdown = Regex.replace(~r"!*\[", markdown, "[")

    # Second, link ATL identifiers.
    markdown = Regex.replace(@identifier_regex, markdown, " [\\1](/incidents/\\1)")

    markdown =
      Regex.replace(
        @identifier_with_media_version_regex,
        markdown,
        " [\\1](/incidents/\\2/detail/\\3)"
      )

    # Third, turn @'s into links.
    markdown = Regex.replace(@tag_regex, markdown, " [@\\3](/profile/\\3)")

    # Setup to open external links in a new tab + add nofollow/noopener, and truncate long links.
    add_target = fn node ->
      if is_nil(Earmark.AstTools.find_att_in_node(node, "href", "")) do
        node
      else
        Earmark.AstTools.merge_atts_in_node(node, target: "_blank", rel: "nofollow noopener")
      end
    end

    truncate_long_links = fn node ->
      case node do
        {tag, atts, [content], m} when tag == "a" and is_binary(content) ->
          {:replace, {tag, atts, [truncate(content, 50)], m}}

        _ ->
          node
      end
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

    options = [
      registered_processors: [{"a", add_target}, {"a", detect_tags}, {"a", truncate_long_links}]
    ]

    # Strip all tags and render markdown
    markdown = markdown |> Earmark.as_html!(options)

    # Perform another round of cleaning (images will be stripped here too)
    markdown = markdown |> HtmlSanitizeEx.Scrubber.scrub(Platform.Security.UgcSanitizer)

    markdown
  end

  @spec escape_markdown_string(String.t()) :: String.t()
  @doc """
  Escape the given string so that it can be used in a markdown document without
  causing formatting issues. Note that this function is not "load bearing" from
  a security perspective; it's just for formatting. There should be no way to
  render markdown on Atlos that is not properly sanitized, regardless of whether
  or not this function is used.
  """
  def escape_markdown_string(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("`", "\\`")
    |> String.replace("*", "\\*")
    |> String.replace("_", "\\_")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("#", "\\#")
    |> String.replace("+", "\\+")
    |> String.replace("-", "\\-")
    |> String.replace(".", "\\.")
    |> String.replace("!", "\\!")
  end

  def generate_qrcode(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: 264)
    |> Phoenix.HTML.raw()
  end

  def generate_recovery_codes(n \\ 10) do
    Enum.map(1..n, fn _ ->
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()
      |> rem(100000000)
      |> Integer.to_string()
      |> String.pad_leading(8, "0")
    end)
  end

  def format_recovery_code(code) do
    code
    |> String.split("", trim: true)
    |> Enum.chunk_every(4)
    |> Enum.map(&Enum.join(&1))
    |> Enum.join(" ")
  end

  def get_instance_name() do
    System.get_env("INSTANCE_NAME")
  end

  def get_instance_version() do
    System.get_env("APP_REVISION", "unknown")
  end

  def get_runtime_information() do
    System.get_env("CONTAINER_APP_REPLICA_NAME", "replica info unknown")
  end

  def text_search(search_terms, queryable) do
    # First, detect if they have entered a slug with a project code into the query. If so, we add a version of the slug without the project code to the query.
    # This is to make it possible to search for "ATL-123" and get results for "123".
    # This is a bit hacky, but it works.
    search_terms = Regex.replace(@identifier_regex_with_project_and_no_tags, search_terms, "\\2")

    wrapped =
      if String.starts_with?(search_terms, "\""), do: search_terms, else: "\"#{search_terms}\""

    queryable
    |> where(
      [q],
      fragment("? @@ websearch_to_tsquery('simple', ?)", q.searchable, ^search_terms) or
        fragment("? @@ websearch_to_tsquery('simple', ?)", q.searchable, ^wrapped)
    )
  end
end
