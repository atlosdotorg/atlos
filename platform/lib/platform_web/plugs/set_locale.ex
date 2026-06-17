defmodule PlatformWeb.Plugs.SetLocale do
  import Plug.Conn

  @supported_locales ["en", "pt_BR"]

  def init(default), do: default

  def call(conn, _opts) do
    locale =
      cond do
        conn.params["locale"] in @supported_locales -> conn.params["locale"]
        get_session(conn, "locale") in @supported_locales -> get_session(conn, "locale")
        true -> "en"
      end

    Gettext.put_locale(PlatformWeb.Gettext, locale)

    conn
    |> put_session("locale", locale)
    |> assign(:locale, locale)
  end
end
