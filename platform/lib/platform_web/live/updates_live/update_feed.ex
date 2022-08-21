defmodule PlatformWeb.UpdatesLive.UpdateFeed do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates

  def update(
        assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show_final_line, fn -> true end)
     |> assign_new(:reverse, fn -> false end)
     |> assign_new(:show_media, fn -> false end)}
  end

  def can_user_change_visibility(user) do
    Accounts.is_privileged(user)
  end

  def handle_event("change_visibility", %{"update" => update_id}, socket) do
    with true <- can_user_change_visibility(socket.assigns.current_user) do
      update = Updates.get_update!(update_id)

      case Updates.update_update_from_changeset(
             Updates.change_update_visibility(update, !update.hidden)
           ) do
        {:ok, _} ->
          # We query because we need to preload the important fields
          modified = Updates.get_update!(update_id)

          {:noreply,
           socket
           |> assign(
             :updates,
             Enum.map(socket.assigns.updates, &if(&1.id == modified.id, do: modified, else: &1))
           )}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp order(updates, reverse) do
    o = Enum.sort_by(updates, & &1.inserted_at, NaiveDateTime)
    if reverse, do: o |> Enum.reverse(), else: o
  end

  def render(assigns) do
    to_show =
      assigns.updates
      |> Enum.filter(&Updates.can_user_view(&1, assigns.current_user))
      |> order(assigns.reverse)
      |> Enum.with_index()

    ~H"""
    <div class="flow-root">
      <ul role="list" class="-mb-8">
        <%= if length(to_show) == 0 do %>
          <p class="mb-8 text-gray-600">There are no updates to show.</p>
        <% end %>
        <%= for {update, idx} <- to_show do %>
          <li class={if update.hidden, do: "opacity-50", else: ""}>
            <.update_entry
              update={update}
              current_user={@current_user}
              show_line={idx != length(to_show) - 1 || @show_final_line}
              show_media={@show_media}
              can_user_change_visibility={can_user_change_visibility(@current_user)}
              target={@myself}
              socket={@socket}
            />
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
