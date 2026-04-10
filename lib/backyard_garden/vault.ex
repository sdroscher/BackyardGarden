defmodule BackyardGarden.Vault do
  @moduledoc "Cloak encryption vault for sensitive fields (Prowl API key)."

  use Cloak.Vault, otp_app: :backyard_garden
end
