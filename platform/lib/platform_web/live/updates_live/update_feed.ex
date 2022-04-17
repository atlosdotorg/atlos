defmodule PlatformWeb.UpdatesLive.UpdateFeed do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates
  alias Platform.Material.Attribute

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
    o = Enum.sort_by(updates, & &1.inserted_at)
    if reverse, do: o |> Enum.reverse(), else: o
  end

  def render(assigns) do
    ~H"""
    <div class="flow-root">
      <ul role="list" class="-mb-8">
        <% to_show = @updates |> Enum.filter(&(Updates.can_user_view(&1, @current_user))) |> order(@reverse) |> Enum.with_index() %>
        <%= if length(to_show) == 0 do %>
          <p class="mb-8 text-gray-600">There are no updates to show.</p>
        <% end %>
        <%= for {update, idx} <- to_show do %>
        <li class={if update.hidden, do: "opacity-50", else: ""}>
          <div class="relative pb-8 group">
            <%= if idx != length(to_show) - 1 || @show_final_line do %>
              <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
            <% end %>
            <div class="relative flex items-start space-x-3">
              <div class="relative">
                <img class="h-10 w-10 rounded-full bg-gray-400 flex items-center justify-center ring-8 ring-white shadow" src={Accounts.get_profile_photo_path(update.user)} alt={"Profile photo for #{update.user.username}"}>
              </div>
              <div class="min-w-0 flex-1 flex flex-col flex-grow">
                <div>
                  <div class="text-sm text-gray-600 mt-2">
                    <%= if @show_media do %>
                      <%= live_patch class: "text-button text-gray-800 inline-block mr-2", to: Routes.media_show_path(@socket, :show, update.media.slug) do %>
                        <%= update.media.slug %>  &nearr;
                      <% end %>
                    <% end %>
                    <.user_text user={update.user} />
                    <%= case update.type do %>
                      <% :update_attribute -> %>
                        updated
                        <%= if Attribute.can_user_edit(Attribute.get_attribute(update.modified_attribute), @current_user, update.media) do %>
                          <%= live_patch class: "text-button text-gray-800 inline-block", to: Routes.media_show_path(@socket, :edit, update.media.slug, update.modified_attribute) do %>
                            <%= Attribute.get_attribute(update.modified_attribute).label %>  &nearr;
                          <% end %>
                        <% else %>
                          <p class="font-medium text-gray-800 inline-block">
                            <%= Attribute.get_attribute(update.modified_attribute).label %>
                          </p>
                        <% end %>
                      <% :create -> %>
                        added <span class="font-medium text-gray-900"><%= update.media.slug %></span>
                      <% :upload_version -> %>
                        uploaded <a href={"#version-#{update.media_version.id}"} class="text-button text-gray-800">media &nearr;</a>
                      <% :comment -> %>
                        commented
                    <% end %>
                    <.rel_time time={update.inserted_at} />
                    <%= if update.hidden do %>
                      <span class="badge ~neutral">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 mr-1" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M3.707 2.293a1 1 0 00-1.414 1.414l14 14a1 1 0 001.414-1.414l-1.473-1.473A10.014 10.014 0 0019.542 10C18.268 5.943 14.478 3 10 3a9.958 9.958 0 00-4.512 1.074l-1.78-1.781zm4.261 4.26l1.514 1.515a2.003 2.003 0 012.45 2.45l1.514 1.514a4 4 0 00-5.478-5.478z" clip-rule="evenodd" />
                          <path d="M12.454 16.697L9.75 13.992a4 4 0 01-3.742-3.741L2.335 6.578A9.98 9.98 0 00.458 10c1.274 4.057 5.065 7 9.542 7 .847 0 1.669-.105 2.454-.303z" />
                        </svg>
                        Hidden
                      </span>
                    <% end %>
                    <%= if can_user_change_visibility(@current_user) do %>
                      <button type="button" phx-target={@myself} phx-click="change_visibility" phx-value-update={update.id} class="opacity-0 group-hover:opacity-100 text-critical-700 transition text-xs ml-2" data-confirm="Are you sure you want to change the visibility of this update?">
                        <%= if update.hidden, do: "Show", else: "Hide" %>
                      </button>
                    <% end %>
                  </div>
                </div>

                <%= if update.type == :update_attribute || update.explanation do %>
                  <div class="mt-1 text-sm text-gray-700 border border-gray-300 rounded-lg shadow-sm overflow-hidden flex flex-col divide-y">
                    <!-- Update detail section -->
                    <%= if update.type == :update_attribute do %>
                      <div class="bg-gray-50 p-2 flex">
                        <div class="flex-grow">
                          <.attr_diff name={update.modified_attribute} old={Jason.decode!(update.old_value)} new={Jason.decode!(update.new_value)} />
                        </div>
                      </div>
                    <% end %>

                    <!-- Text comment section -->
                    <%= if update.explanation do %>
                      <div class="p-2">
                        <p><%= update.explanation %></p>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
