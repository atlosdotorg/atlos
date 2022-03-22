defmodule PlatformWeb.SettingsLive.ResiliencyComponent do
  use PlatformWeb, :live_component

  def render(assigns) do
    ~H"""
    <article class="relative block w-full border-2 border-gray-300 border-dashed rounded-lg p-12 text-center">
      <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
      </svg>
      <span class="mt-2 block text-sm font-medium text-gray-900"> These features are coming soon. </span>
    </article>
    """
  end
end
