defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Media")
     |> assign(:media, list_media(socket))
     |> assign(:changeset, changeset())}
  end

  def changeset(params \\ %{}) do
    data = %{}
    types = %{query: :string}

    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_length(:query, max: 256)
  end

  def handle_event("validate", %{"search" => params}, socket) do
    c =
      changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, c)}
  end

  def handle_event("save", %{"search" => params}, socket) do
    c = changeset(params)

    if c.valid? do
      {:noreply, socket |> assign(:changeset, c) |> assign(:media, list_media(c.changes))}
    else
      {:noreply, socket |> assign(:changeset, c)}
    end
  end

  def list_media(_socket, _query \\ %{}) do
    Material.list_media()
  end
end
