defmodule BackyardGardenWeb.Seeds.EditLive do
  @moduledoc """
  LiveView for editing an existing seed's fields.
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Seeds
  alias BackyardGarden.Seeds.Seed

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    seed = Seeds.get_seed!(id)

    if seed.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "Seed not found.")
       |> push_navigate(to: ~p"/seeds")}
    else
      changeset = Seed.changeset(seed, %{})
      {:ok, assign(socket, seed: seed, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Edit #{socket.assigns.seed.name}")}
  end

  @impl true
  def handle_event("validate", %{"seed" => params}, socket) do
    changeset =
      socket.assigns.seed
      |> Seed.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"seed" => params}, socket) do
    case Seeds.update_seed(socket.assigns.seed, params) do
      {:ok, seed} ->
        {:noreply,
         socket
         |> put_flash(:info, "Seed updated successfully.")
         |> push_navigate(to: ~p"/seeds/#{seed.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
