defmodule PlatformWeb.NotificationsLive.NotificationsList do
  use PlatformWeb, :live_component
  alias Platform.Notifications

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_notifications()}
  end

  defp assign_notifications(socket, extend \\ [], opts \\ []) do
    result =
      Notifications.get_notifications_by_user_paginated(
        socket.assigns.current_user,
        opts
      )

    socket |> assign(:result, result) |> assign(:notifications, extend ++ result.entries)
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.result.metadata.after

    {:noreply, socket |> assign_notifications(socket.assigns.notifications, after: cursor_after)}
  end

  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_notifications_as_read(socket.assigns.current_user)

    {:noreply, socket |> assign_notifications()}
  end

  def handle_event("toggle_notification_read", %{"notification" => id}, socket) do
    notification = socket.assigns.notifications |> Enum.find(&(to_string(&1.id) == id))
    {:ok, _} = Notifications.update_notification(notification, %{read: not notification.read})

    {:noreply,
     socket
     |> assign(
       :notifications,
       socket.assigns.notifications
       |> Enum.map(fn n ->
         # Manually mark that notification as read, without hitting the database again
         if n.id == notification.id, do: n |> Map.put(:read, not notification.read), else: n
       end)
     )}
  end

  def handle_event("delete_notification", %{"notification" => id}, socket) do
    notification = socket.assigns.notifications |> Enum.find(&(to_string(&1.id) == id))
    {:ok, _} = Notifications.delete_notification(notification)

    {:noreply,
     socket
     |> assign(
       :notifications,
       socket.assigns.notifications
       |> Enum.filter(fn n ->
         # Manually remove that notification, without hitting the database again
         n.id != notification.id
       end)
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.card no_pad={true} class="overflow-hidden">
        <%= if Enum.empty?(@notifications) do %>
          <div class="text-center my-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="mx-auto h-12 w-12 text-gray-400"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"
              />
            </svg>

            <h3 class="mt-2 text-sm font-medium text-gray-900">No notifications</h3>
            <p class="mt-1 text-sm text-gray-500">
              Notifications will appear here when you're tagged or someone updates an incident you're subscribed to.
            </p>
          </div>
        <% else %>
          <ul class="flex flex-col overflow-hidden divide-y">
            <%= for notification <- @notifications do %>
              <div class="block px-2 pb-2 pt-4 -mb-6 flex group relative hover:bg-urge-50 focus-within:bg-urge-50 bg-white">
                <%= if not notification.read do %>
                  <div
                    phx-click="toggle_notification_read"
                    phx-value-notification={notification.id}
                    phx-target={@myself}
                    tab-index="0"
                    data-tooltip="Mark as read"
                    class="mr-2 mt-3 cursor-pointer text-urge-600"
                  >
                    <svg
                      viewBox="0 0 100 100"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="currentColor"
                      class="h-3 w-3"
                    >
                      <circle cx="50" cy="50" r="50" />
                    </svg>
                    <span class="sr-only">
                      Unread notification
                    </span>
                  </div>
                <% else %>
                  <div class="mr-2 mt-3 cursor-pointer text-transparent">
                    <svg
                      viewBox="0 0 100 100"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="currentColor"
                      class="h-3 w-3"
                    >
                      <circle cx="50" cy="50" r="50" />
                    </svg>
                  </div>
                <% end %>
                <div class="flex-grow">
                  <%= case notification.type do %>
                    <% :update -> %>
                      <.update_entry
                        update={notification.update}
                        show_line={false}
                        show_media={true}
                        can_user_change_visibility={false}
                        current_user={@current_user}
                        target={@myself}
                        socket={@socket}
                        left_indicator={:profile}
                        profile_ring={false}
                      />
                    <% :message -> %>
                      <div class="flex mb-6 gap-3 w-full">
                        <div class="rounded-full flex-shrink-0 bg-neutral-200 -mt-px h-10 w-10 text-neutral-500 flex items-center justify-around">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                            fill="currentColor"
                            class="w-6 h-6"
                          >
                            <path d="M16.881 4.346A23.112 23.112 0 018.25 6H7.5a5.25 5.25 0 00-.88 10.427 21.593 21.593 0 001.378 3.94c.464 1.004 1.674 1.32 2.582.796l.657-.379c.88-.508 1.165-1.592.772-2.468a17.116 17.116 0 01-.628-1.607c1.918.258 3.76.75 5.5 1.446A21.727 21.727 0 0018 11.25c0-2.413-.393-4.735-1.119-6.904zM18.26 3.74a23.22 23.22 0 011.24 7.51 23.22 23.22 0 01-1.24 7.51c-.055.161-.111.322-.17.482a.75.75 0 101.409.516 24.555 24.555 0 001.415-6.43 2.992 2.992 0 00.836-2.078c0-.806-.319-1.54-.836-2.078a24.65 24.65 0 00-1.415-6.43.75.75 0 10-1.409.516c.059.16.116.321.17.483z" />
                          </svg>
                        </div>
                        <div class="prose prose-sm block mt-2 mb-4 grow !max-w-full rounded-lg">
                          <%= raw(notification.content |> Platform.Utils.render_markdown()) %>
                        </div>
                      </div>
                  <% end %>
                </div>
                <div class="hidden shadow-urge-lg group-hover:flex group-focus-within:flex gap-1 absolute top-0 right-0 p-2 text-sm">
                  <button
                    class="text-button"
                    phx-click="toggle_notification_read"
                    phx-value-notification={notification.id}
                    phx-target={@myself}
                    data-tooltip={if notification.read, do: "Mark as unread", else: "Mark as unread"}
                  >
                    <%= if notification.read do %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        class="w-5 h-5"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M15.312 11.424a5.5 5.5 0 01-9.201 2.466l-.312-.311h2.433a.75.75 0 000-1.5H3.989a.75.75 0 00-.75.75v4.242a.75.75 0 001.5 0v-2.43l.31.31a7 7 0 0011.712-3.138.75.75 0 00-1.449-.39zm1.23-3.723a.75.75 0 00.219-.53V2.929a.75.75 0 00-1.5 0V5.36l-.31-.31A7 7 0 003.239 8.188a.75.75 0 101.448.389A5.5 5.5 0 0113.89 6.11l.311.31h-2.432a.75.75 0 000 1.5h4.243a.75.75 0 00.53-.219z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    <% else %>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        class="w-5 h-5"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    <% end %>
                  </button>
                </div>
              </div>
            <% end %>
          </ul>
        <% end %>
      </.card>
      <div class="mx-auto text-center items-center justify-center text-xs my-4 flex gap-8">
        <%= if !is_nil(@result.metadata.after) do %>
          <button
            type="button"
            class="text-button"
            phx-click="load_more"
            phx-disable-with="Loading..."
            phx-target={@myself}
          >
            Load More
          </button>
        <% end %>
        <%= if Notifications.has_unread_notifications(@current_user) do %>
          <button
            type="button"
            class="text-button"
            phx-click="mark_all_read"
            phx-disable-with="Processing..."
            phx-target={@myself}
          >
            Mark All Read
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
