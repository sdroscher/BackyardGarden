defmodule BackyardGardenWeb.Seeds.NewLive do
  @moduledoc """
  LiveView for adding a seed to the user's personal library.

  Three modes:
  - :catalog — browse/search supplier products and select one to pre-fill
  - :url     — paste a West Coast Seeds or Metchosin Farm URL to fetch and pre-fill
  - :manual  — fill in all fields from scratch
  """

  use BackyardGardenWeb, :live_view

  alias BackyardGarden.{Seeds, SupplierCatalog}
  alias BackyardGarden.Seeds.Seed

  @all_suppliers MapSet.new(["west_coast_seeds", "metchosin_farm"])

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:mode, :catalog)
     |> assign(:catalog_search, "")
     |> assign(:supplier_filters, @all_suppliers)
     |> assign(:supplier_products, SupplierCatalog.list_supplier_products())
     |> assign(:selected_supplier_product, nil)
     |> assign(:url_input, "")
     |> assign(:url_loading, false)
     |> assign(:url_error, nil)
     |> assign(:fetch_task, nil)
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Add Seed")}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:mode, String.to_existing_atom(mode))
     |> assign(:url_error, nil)}
  end

  @impl true
  def handle_event("search_catalog", %{"value" => search}, socket) do
    {:noreply,
     socket
     |> assign(:catalog_search, search)
     |> reload_catalog_products()}
  end

  @impl true
  def handle_event("toggle_supplier", %{"supplier" => supplier}, socket) do
    filters = socket.assigns.supplier_filters

    new_filters =
      if MapSet.member?(filters, supplier),
        do: MapSet.delete(filters, supplier),
        else: MapSet.put(filters, supplier)

    {:noreply,
     socket
     |> assign(:supplier_filters, new_filters)
     |> reload_catalog_products()}
  end

  @impl true
  def handle_event("select_supplier_product", %{"id" => id}, socket) do
    product = SupplierCatalog.get_supplier_product!(id)
    form = prefill_form(prefill_attrs(product))
    {:noreply, socket |> assign(:selected_supplier_product, product) |> assign(:form, form)}
  end

  @impl true
  def handle_event("set_url", %{"value" => url}, socket) do
    {:noreply, assign(socket, :url_input, url)}
  end

  @impl true
  def handle_event("fetch_url", _params, socket) do
    if socket.assigns.fetch_task, do: Task.shutdown(socket.assigns.fetch_task, :brutal_kill)

    url = socket.assigns.url_input
    task = Task.async(fn -> SupplierCatalog.fetch_and_upsert_by_url(url) end)

    {:noreply,
     socket
     |> assign(:url_loading, true)
     |> assign(:url_error, nil)
     |> assign(:fetch_task, task)}
  end

  @impl true
  def handle_event("validate", %{"seed" => params}, socket) do
    form =
      %Seed{}
      |> Seed.changeset(Map.put(params, "user_id", socket.assigns.current_user.id))
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"seed" => params}, socket) do
    case Seeds.create_seed_for_user(socket.assigns.current_user.id, params) do
      {:ok, seed} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{seed.name} added to your library.")
         |> push_navigate(to: ~p"/seeds/#{seed.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_info({ref, result}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, product} ->
        form = prefill_form(prefill_attrs(product))

        {:noreply,
         socket
         |> assign(:url_loading, false)
         |> assign(:url_error, nil)
         |> assign(:selected_supplier_product, product)
         |> assign(:form, form)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:url_loading, false)
         |> assign(:url_error, reason)}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, :url_loading, false)}
  end

  # --- Private helpers ---

  defp reload_catalog_products(socket) do
    %{catalog_search: search, supplier_filters: filters} = socket.assigns

    suppliers =
      if MapSet.equal?(filters, @all_suppliers),
        do: nil,
        else: MapSet.to_list(filters)

    products = SupplierCatalog.list_supplier_products(%{search: search, suppliers: suppliers})
    assign(socket, :supplier_products, products)
  end

  defp blank_form do
    %Seed{} |> Seed.changeset(%{}) |> to_form()
  end

  defp prefill_form(attrs) do
    %Seed{} |> Seed.changeset(attrs) |> to_form()
  end

  defp prefill_attrs(sp) do
    %{
      "name" => sp.title,
      "brand" => supplier_to_brand(sp.supplier),
      "source_url" => sp.url,
      "supplier_product_id" => sp.id
    }
  end

  defp supplier_to_brand("west_coast_seeds"), do: "West Coast Seeds"
  defp supplier_to_brand("metchosin_farm"), do: "Metchosin Farm"
  defp supplier_to_brand(other), do: other
end
