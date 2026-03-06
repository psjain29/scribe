defmodule SocialScribe.CRM.Providers.HubspotProvider do
  @moduledoc """
  Thin HubSpot adapter for the CRM provider contract.

  Delegates directly to the existing HubSpot API behavior to preserve current
  production behavior and test seams.
  """

  @behaviour SocialScribe.CRM.ProviderBehaviour

  alias SocialScribe.HubspotApiBehaviour

  @impl SocialScribe.CRM.ProviderBehaviour
  def search_contacts(credential, query) do
    HubspotApiBehaviour.search_contacts(credential, query)
  end

  @impl SocialScribe.CRM.ProviderBehaviour
  def get_contact(credential, contact_id) do
    HubspotApiBehaviour.get_contact(credential, contact_id)
  end

  @impl SocialScribe.CRM.ProviderBehaviour
  def update_contact(credential, contact_id, updates) do
    HubspotApiBehaviour.update_contact(credential, contact_id, updates)
  end
end
