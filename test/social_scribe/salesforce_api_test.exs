defmodule SocialScribe.SalesforceApiTest do
  use SocialScribe.DataCase

  import SocialScribe.AccountsFixtures
  import Tesla.Mock

  alias SocialScribe.Accounts
  alias SocialScribe.SalesforceApi

  setup do
    original_oauth = Application.get_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, [])
    original_adapter = Application.get_env(:tesla, :adapter)

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    Application.put_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth,
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      redirect_uri: "http://localhost:4000/auth/salesforce/callback",
      site: "https://login.salesforce.com"
    )

    on_exit(fn ->
      Application.put_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, original_oauth)
      Application.put_env(:tesla, :adapter, original_adapter)
    end)

    :ok
  end

  test "search_contacts/2 sends SOSL and returns stable shape" do
    credential = salesforce_credential_fixture()

    mock(fn
      %{
        method: :get,
        url: "https://example.my.salesforce.com/services/data/v61.0/search",
        query: query
      } ->
        assert query[:q] ==
                 "FIND {o\\\\'hara} IN ALL FIELDS RETURNING Contact(Id, Name, Email, Phone LIMIT 10)"

        %Tesla.Env{
          status: 200,
          body: %{
            "searchRecords" => [
              %{
                "Id" => "0031",
                "Name" => "O'Hara",
                "Email" => "ohara@example.com",
                "Phone" => "5551112222"
              }
            ]
          }
        }
    end)

    assert {:ok, [%{id: "0031", name: "O'Hara", email: "ohara@example.com", phone: "5551112222"}]} =
             SalesforceApi.search_contacts(credential, "o'hara")
  end

  test "search_contacts/2 refreshes token and retries once after 401" do
    credential =
      salesforce_credential_fixture(%{
        token: "expired_token",
        refresh_token: "refresh_token_1",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    parent = self()

    mock(fn
      %{
        method: :get,
        url: "https://example.my.salesforce.com/services/data/v61.0/search",
        headers: headers
      } ->
        auth =
          List.keyfind(headers, "authorization", 0) || List.keyfind(headers, "Authorization", 0)

        send(parent, {:auth_header, auth})

        case auth do
          {_, "Bearer expired_token"} ->
            %Tesla.Env{status: 401, body: %{"errorCode" => "INVALID_SESSION_ID"}}

          {_, "Bearer new_access_token"} ->
            %Tesla.Env{status: 200, body: %{"searchRecords" => []}}
        end

      %{method: :post, url: "https://login.salesforce.com/services/oauth2/token", body: body} ->
        params = refresh_params(body)

        assert params["grant_type"] == "refresh_token"
        assert params["refresh_token"] == "refresh_token_1"
        assert params["client_id"] == "test_client_id"
        assert params["client_secret"] == "test_client_secret"

        %Tesla.Env{
          status: 200,
          body: %{
            "access_token" => "new_access_token",
            "refresh_token" => "refresh_token_2",
            "instance_url" => "https://example.my.salesforce.com",
            "id" => "https://login.salesforce.com/id/00D/005",
            "expires_in" => 7200
          }
        }
    end)

    assert {:ok, []} = SalesforceApi.search_contacts(credential, "john")

    assert_receive {:auth_header, {_, "Bearer expired_token"}}
    assert_receive {:auth_header, {_, "Bearer new_access_token"}}

    refreshed = Accounts.get_user_credential!(credential.id)
    assert refreshed.token == "new_access_token"
    assert refreshed.refresh_token == "refresh_token_2"
    assert refreshed.metadata["instance_url"] == "https://example.my.salesforce.com"
  end

  test "update_contact/3 sends only allowlisted fields" do
    credential = salesforce_credential_fixture()

    updates = %{
      "Phone" => "5551234567",
      "Title" => "CTO",
      "BogusField__c" => "ignore-me"
    }

    mock(fn
      %{
        method: :patch,
        url: "https://example.my.salesforce.com/services/data/v61.0/sobjects/Contact/0031",
        body: body
      } ->
        payload = patch_payload(body)

        assert payload == %{"Phone" => "5551234567", "Title" => "CTO"}
        refute Map.has_key?(payload, "BogusField__c")

        %Tesla.Env{status: 204, body: ""}
    end)

    assert {:ok, %{"Phone" => "5551234567", "Title" => "CTO", "Id" => "0031"}} =
             SalesforceApi.update_contact(credential, "0031", updates)
  end

  defp refresh_params(params) when is_map(params), do: params
  defp refresh_params(params) when is_binary(params), do: URI.decode_query(params)

  defp patch_payload(payload) when is_map(payload), do: payload
  defp patch_payload(payload) when is_binary(payload), do: Jason.decode!(payload)
end
