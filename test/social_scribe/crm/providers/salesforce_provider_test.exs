defmodule SocialScribe.CRM.Providers.SalesforceProviderTest do
  use ExUnit.Case, async: false

  import Mox

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.CRM
  alias SocialScribe.CRM.Providers.SalesforceProvider

  setup :verify_on_exit!

  setup do
    credential = %UserCredential{provider: "salesforce", token: "token", uid: "sf_123"}
    %{credential: credential}
  end

  test "SalesforceProvider.search_contacts/2 delegates to SalesforceApiBehaviour", %{
    credential: credential
  } do
    expected = [%{id: "0031", name: "Jane Doe", email: "jane@example.com", phone: "5551112222"}]

    SocialScribe.SalesforceApiMock
    |> expect(:search_contacts, fn ^credential, "jane" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = SalesforceProvider.search_contacts(credential, "jane")
  end

  test "SalesforceProvider.get_contact/2 delegates to SalesforceApiBehaviour", %{
    credential: credential
  } do
    expected = %{id: "0031", name: "Jane Doe", email: "jane@example.com"}

    SocialScribe.SalesforceApiMock
    |> expect(:get_contact, fn ^credential, "0031" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = SalesforceProvider.get_contact(credential, "0031")
  end

  test "SalesforceProvider.update_contact/3 delegates to SalesforceApiBehaviour", %{
    credential: credential
  } do
    updates = %{"Phone" => "5559990000"}
    expected = %{id: "0031", phone: "5559990000"}

    SocialScribe.SalesforceApiMock
    |> expect(:update_contact, fn ^credential, "0031", ^updates ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = SalesforceProvider.update_contact(credential, "0031", updates)
  end

  test "CRM dispatcher routes salesforce provider", %{credential: credential} do
    expected = [%{id: "0031", name: "John Smith", email: "john@example.com", phone: nil}]

    SocialScribe.SalesforceApiMock
    |> expect(:search_contacts, fn ^credential, "john" ->
      {:ok, expected}
    end)

    assert {:ok, ^expected} = CRM.search_contacts(credential, "john")
  end
end
