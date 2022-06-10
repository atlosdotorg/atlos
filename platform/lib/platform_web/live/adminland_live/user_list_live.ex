defmodule PlatformWeb.AdminlandLive.UserListLive do
  use PlatformWeb, :live_component
  alias Platform.Accounts

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(:results, Accounts.get_all_users())}
  end

  def render(assigns) do
    ~H"""
    <section>
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-white">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      User
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Bio
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Invited By
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Joined
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Edit</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for user <- @results do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                        <div class="flex items-center">
                          <div class="h-10 w-10 flex-shrink-0">
                            <img
                              class="relative z-30 inline-block h-10 w-10 rounded-full ring-2 ring-white"
                              src={Accounts.get_profile_photo_path(user)}
                              title={user.username}
                              alt={"Profile photo for #{user.username}"}
                            />
                          </div>
                          <div class="ml-4">
                            <%= live_patch(
                              to: "/profile/#{user.username}",
                              class: "text-button group outline-none"
                            ) do %>
                              <div class="outline-none font-medium text-gray-900 group-focus:text-urge-600">
                                <.user_text user={user} />
                              </div>
                              <div class="outline-none text-gray-500"><%= user.email %></div>
                            <% end %>
                          </div>
                        </div>
                      </td>
                      <td class="max-w-md px-3 py-4 text-sm text-gray-500">
                        <%= for item <- user.restrictions || [] do %>
                          <span class="chip ~critical mb-1"><%= item %></span>
                        <% end %>
                        <%= for item <- user.roles || [] do %>
                          <span class="chip ~positive mb-1"><%= item %></span>
                        <% end %>
                      </td>
                      <td class="max-w-md px-3 py-4 text-sm text-gray-500">
                        <%= user.bio %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <%= case user.invite do %>
                          <% nil -> %>
                            (none)
                          <% invite -> %>
                            <.user_text user={invite.owner} />
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <.rel_time time={user.inserted_at} />
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <%= live_patch("Edit",
                          to: "/profile/#{user.username}/edit",
                          class: "text-button"
                        ) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
