defmodule BackyardGardenWeb.NavHooks do
  @moduledoc """
  LiveView lifecycle hooks that make the current request path available
  as `@current_path` in every LiveView and its layout.

  Attached via `on_mount` in the `live_view` macro so it runs automatically
  for all LiveViews without requiring per-view boilerplate.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign_current_path()
      |> attach_hook(:update_current_path, :handle_params, fn _params, url, socket ->
        uri = URI.parse(url)
        {:cont, assign(socket, :current_path, uri.path)}
      end)

    {:cont, socket}
  end

  defp assign_current_path(socket) do
    path =
      case socket.host_uri do
        %URI{path: path} when is_binary(path) -> path
        _ -> "/"
      end

    assign(socket, :current_path, path)
  end
end
