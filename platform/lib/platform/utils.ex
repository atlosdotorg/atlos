defmodule Platform.Utils do
  @moduledoc """
  Utilities for the platform.
  """

  def generate_media_slug() do
    slug =
      "ATL-" <>
        for _ <- 1..6, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>

    if !is_nil(Platform.Material.get_full_media_by_slug(slug)) do
      generate_media_slug()
    else
      slug
    end
  end

  def generate_random_sequence(length) do
    for _ <- 1..length, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
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

    if Mix.env() == :test do
      true
    else
      if is_nil(token) or String.length(token) == 0 do
        false
      else
        {:ok, status, headers, body} =
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

    # First, strip images.
    stripped_images = Regex.replace(~r"!*\[", markdown, "[")

    # Second, link ATL identifiers.
    preprocessed = Regex.replace(~r/(ATL-[A-Z0-9]{6})/, stripped_images, "[\\0](/media/\\0)")

    # Manually kill images!
    preprocessed |> Earmark.as_html!()
  end
end
