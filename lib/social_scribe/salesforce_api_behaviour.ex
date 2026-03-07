defmodule SocialScribe.SalesforceApiBehaviour do
  @moduledoc """
  Behaviour for Salesforce contact operations.

  Search results should use a stable shape: `%{id, name, email, phone}`.
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

  @doc """
  Delegates contact search to the configured Salesforce API implementation.
  """
  def search_contacts(credential, query) do
    impl().search_contacts(credential, query)
  end

  @doc """
  Delegates contact fetch to the configured Salesforce API implementation.
  """
  def get_contact(credential, contact_id) do
    impl().get_contact(credential, contact_id)
  end

  @doc """
  Delegates contact updates to the configured Salesforce API implementation.
  """
  def update_contact(credential, contact_id, updates) do
    impl().update_contact(credential, contact_id, updates)
  end

  defp impl do
    Application.get_env(:social_scribe, :salesforce_api, SocialScribe.SalesforceApi)
  end
end
