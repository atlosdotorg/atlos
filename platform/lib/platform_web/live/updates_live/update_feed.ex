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

  def combine_and_sort_updates(updates, should_combine \\ true) do
    updates
    |> Enum.sort_by(& &1.inserted_at, NaiveDateTime)
    |> Enum.reduce([], fn elem, acc ->
      case acc do
        [] ->
          [elem]

        [head | tail] ->
          last_update =
            case head do
              [newest | _] -> newest
              other -> other
            end

          # Items are combinable if they were done by the same user, neither have an explanation, and are less than fifteen minutes apart. Updates intended to be hidden should have already been filtered out before calling this function.
          if should_combine and last_update.user == elem.user and
               NaiveDateTime.diff(last_update.inserted_at, elem.inserted_at) < 15 * 60 and
               is_nil(last_update.explanation) and is_nil(elem.explanation) and
               last_update.type == :update_attribute and elem.type == :update_attribute do
            combine_with = if is_list(head), do: head, else: [head]
            [[elem] ++ combine_with] ++ tail
          else
            [elem, head] ++ tail
          end
      end
    end)
    |> Enum.reverse()
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

  defp reorder(updates, reverse) do
    if reverse, do: updates |> Enum.reverse(), else: updates
  end

  def render(assigns) do
    to_show =
      assigns.updates
      |> Enum.filter(&Updates.can_user_view(&1, assigns.current_user))
      |> combine_and_sort_updates(Map.get(assigns, :should_combine, true))
      |> reorder(assigns.reverse)
      |> Enum.with_index()

    ~H"""
    <div class="flow-root">
      <ul role="list" class="-mb-8">
        <%= if length(to_show) == 0 do %>
          <p class="mb-8 text-gray-600">There are no updates to show.</p>
        <% end %>
        <%= for {update, idx} <- to_show do %>
          <.update_entry
            update={update}
            current_user={@current_user}
            show_line={idx != length(to_show) - 1 || @show_final_line}
            show_media={@show_media}
            can_user_change_visibility={can_user_change_visibility(@current_user)}
            target={@myself}
            socket={@socket}
            show_profile={true}
          />
        <% end %>
      </ul>
    </div>
    """
  end
end
