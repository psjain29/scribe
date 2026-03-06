defmodule SocialScribe.CRM do
  @moduledoc """
  CRM provider dispatcher.

  Provider-specific implementations are selected from the credential's provider
  value. This keeps orchestration code provider-agnostic while preserving
  existing integrations.
  """

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.CRM.Providers.HubspotProvider

  @providers %{
    "hubspot" => HubspotProvider
  }

  def search_contacts(%UserCredential{} = credential, query) do
    with {:ok, provider} <- fetch_provider(credential.provider) do
      provider.search_contacts(credential, query)
    end
  end

  def get_contact(%UserCredential{} = credential, contact_id) do
    with {:ok, provider} <- fetch_provider(credential.provider) do
      provider.get_contact(credential, contact_id)
    end
  end

  def update_contact(%UserCredential{} = credential, contact_id, updates) when is_map(updates) do
    with {:ok, provider} <- fetch_provider(credential.provider) do
      provider.update_contact(credential, contact_id, updates)
    end
  end

  defp fetch_provider(provider) when is_binary(provider) do
    case Map.get(@providers, provider) do
      nil -> {:error, {:unsupported_provider, provider}}
      module -> {:ok, module}
    end
  end
end
