defmodule BackyardGarden.Encrypted.Binary do
  @moduledoc "Cloak encrypted binary field type, backed by BackyardGarden.Vault."

  use Cloak.Ecto.Binary, vault: BackyardGarden.Vault
end
