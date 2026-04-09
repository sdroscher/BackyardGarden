defmodule BackyardGarden.Workers.ProwlClient do
  @moduledoc """
  HTTP client for Prowl API — sends push notifications to iOS devices.
  """

  require Logger

  @prowl_api_url "https://api.prowlapp.com/publicapi/add"

  @doc """
  Send a notification to Prowl.

  Params:
  - `api_key`: User's Prowl API key
  - `opts`: Map with `:event`, `:description`, `:priority` (optional, default 0)

  Returns: `{:ok, body}` or `{:error, reason}`
  """
  def send_notification(nil, _opts) do
    {:error, "No Prowl API key configured"}
  end

  def send_notification(api_key, opts) do
    body =
      [
        apikey: api_key,
        application: "BackyardGarden",
        event: opts[:event] || "Notification",
        description: opts[:description] || "",
        priority: opts[:priority] || 0
      ]
      |> URI.encode_query()

    case Req.post(@prowl_api_url, body: body) do
      {:ok, response} ->
        Logger.info("Prowl notification sent: #{response.status}")
        {:ok, response.body}

      {:error, reason} ->
        Logger.error("Prowl notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
