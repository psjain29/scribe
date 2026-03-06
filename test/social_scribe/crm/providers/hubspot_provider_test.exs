defmodule SocialScribe.CRM.Providers.HubspotProviderTest do
  use ExUnit.Case, async: false

  import Mox

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.CRM
  alias SocialScribe.CRM.Providers.HubspotProvider

  setup :verify_on_exit!

  setup do
    credential = %UserCredential{provider: "hubspot", token: "token", uid: "hub_123"}
    %{credential: credential}
  end

  test "HubspotProvider.search_contacts/2 delegates to HubspotApiBehaviour", %{credential: credential} do
    expected = [%{id: "1", firstname: "Jane", lastname: "Doe"}]

    SocialScribe.HubspotApiMock
    |> expect(:search_contacts, fn ^credential, "jane" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = HubspotProvider.search_contacts(credential, "jane")
  end

  test "HubspotProvider.get_contact/2 delegates to HubspotApiBehaviour", %{credential: credential} do
    expected = %{id: "123", firstname: "Jane", lastname: "Doe"}

    SocialScribe.HubspotApiMock
    |> expect(:get_contact, fn ^credential, "123" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = HubspotProvider.get_contact(credential, "123")
  end

  test "HubspotProvider.update_contact/3 delegates to HubspotApiBehaviour", %{credential: credential} do
    updates = %{"phone" => "555-111-2222"}
    expected = %{id: "123", phone: "555-111-2222"}

    SocialScribe.HubspotApiMock
    |> expect(:update_contact, fn ^credential, "123", ^updates ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = HubspotProvider.update_contact(credential, "123", updates)
  end

  test "CRM dispatcher routes hubspot provider", %{credential: credential} do
    expected = [%{id: "1", firstname: "John"}]

    SocialScribe.HubspotApiMock
    |> expect(:search_contacts, fn ^credential, "john" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = CRM.search_contacts(credential, "john")
  end

  test "CRM dispatcher returns unsupported provider error" do
    credential = %UserCredential{provider: "salesforce", token: "token", uid: "sf_123"}

    assert {:error, {:unsupported_provider, "salesforce"}} =
             CRM.search_contacts(credential, "john")
  end
end
