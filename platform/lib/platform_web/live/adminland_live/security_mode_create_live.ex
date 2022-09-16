defmodule PlatformWeb.AdminlandLive.SecurityModeCreateLive do
  use PlatformWeb, :live_component
  alias Platform.Security
  alias Platform.Auditor

  def update(%{parent_socket: parent_socket} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:parent_socket, parent_socket)
     |> assign(:changeset, Security.change_security_mode(%Security.SecurityMode{}))}
  end

  def assign_local_params(params, socket),
    do: params |> Map.put("user_id", socket.assigns.parent_socket.assigns.current_user.id)

  def handle_event("validate", %{"security_mode" => params}, socket) do
    changeset =
      Security.change_security_mode(
        %Security.SecurityMode{},
        params |> assign_local_params(socket)
      )
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"security_mode" => params}, socket) do
    with true <-
           socket.assigns.parent_socket.assigns.current_user.roles
           |> Enum.member?(:admin)
           |> dbg(),
         {:ok, value} <-
           Security.create_security_mode(params |> assign_local_params(socket)) do
      Auditor.log(
        :security_mode_updated,
        %{description: value.description, mode: value.mode},
        socket.assigns.parent_socket
      )

      {:noreply,
       socket
       |> put_flash(:info, "Security mode set successfully.")
       |> redirect(to: Routes.adminland_index_path(socket, :security))}
    else
      {:error, changeset} -> {:noreply, socket |> assign(:changeset, changeset)}
      # Should never be hit
      _ -> raise "no permission to change security mode"
    end
  end

  def render(assigns) do
    ~H"""
    <section>
      <.form
        let={f}
        for={@changeset}
        id="security-mode-create"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <%= label(
          f,
          :description,
          "User-facing description"
        ) %>
        <%= text_input(f, :description,
          placeholder: "Some user-facing description...",
          phx_debounce: "250"
        ) %>
        <%= error_tag(f, :description) %>
        <p class="support">
          This description will be shown to users when they try to perform a disallowed action (e.g., logging in when mode is "No Access").
        </p>

        <%= label(f, :mode, "What security mode would you like to set?") %>
        <%= select(f, :mode, [Normal: "normal", "Read Only": "read_only", "No Access": "no_access"],
          data_descriptions:
            Jason.encode!(%{
              "normal" => "Everyone can use Atlos normally",
              "read_only" => "Only admins can edit incident data",
              "no_access" => "Only Admins can access Atlos"
            })
        ) %>
        <%= error_tag(f, :mode) %>

        <%= submit(
          "Set security mode",
          phx_disable_with: "Setting...",
          class: "button ~urge @high mt-4"
        ) %>
      </.form>
    </section>
    """
  end
end
