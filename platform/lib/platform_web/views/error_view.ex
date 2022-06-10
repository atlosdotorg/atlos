defmodule PlatformWeb.ErrorView do
  use PlatformWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, assigns) do
    message = Phoenix.Controller.status_message_from_template(template)

    description =
      if String.starts_with?(template, "5") do
        ~H"""
        Atlos experienced an error processing your request. This error has been reported to our team. Please contact us if the issue continues.
        """
      else
        ~H"""
        Please contact us if you believed you are receiving this message in error.
        """
      end

    render(
      "error.html",
      Map.merge(assigns, %{
        title: message,
        message: message,
        description: description
      })
    )
  end
end
