defmodule BackyardGarden.Workers.ProwlClientTest do
  use ExUnit.Case

  alias BackyardGarden.Workers.ProwlClient

  describe "send_notification/2" do
    test "returns error if no prowl_api_key provided" do
      assert {:error, "No Prowl API key configured"} =
               ProwlClient.send_notification(nil, %{
                 event: "Test",
                 description: "Test message"
               })
    end
  end
end
