defmodule SocialScribe.CRM.Providers.SalesforceProvider do
  @moduledoc """
  Thin Salesforce adapter for the CRM provider contract.
  """

  @behaviour SocialScribe.CRM.ProviderBehaviour

  alias SocialScribe.SalesforceApiBehaviour

  @impl SocialScribe.CRM.ProviderBehaviour
  def search_contacts(credential, query) do
    SalesforceApiBehaviour.search_contacts(credential, query)
  end

  @impl SocialScribe.CRM.ProviderBehaviour
  def get_contact(credential, contact_id) do
    SalesforceApiBehaviour.get_contact(credential, contact_id)
  end

  @impl SocialScribe.CRM.ProviderBehaviour
  def update_contact(credential, contact_id, updates) do
    SalesforceApiBehaviour.update_contact(credential, contact_id, updates)
  end
end
