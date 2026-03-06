defmodule SocialScribe.CRM.ProviderBehaviour do
  @moduledoc """
  Provider contract for CRM contact operations.

  This is intentionally small and data-plane focused so providers can be
  introduced without changing the meeting UI orchestration flow.
  """

  alias SocialScribe.Accounts.UserCredential

  @callback search_contacts(credential :: UserCredential.t(), query :: String.t()) ::
              {:ok, list(map())} | {:error, any()}

  @callback get_contact(credential :: UserCredential.t(), contact_id :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback update_contact(
              credential :: UserCredential.t(),
              contact_id :: String.t(),
              updates :: map()
            ) ::
              {:ok, map()} | {:error, any()}
end
