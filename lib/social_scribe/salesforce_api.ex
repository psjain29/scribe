defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce CRM API client for contact operations with token refresh support.

  Contact updates are allowlisted by design to prevent unsafe field writes.
  """

  @behaviour SocialScribe.SalesforceApiBehaviour

  alias SocialScribe.Accounts
  alias SocialScribe.Accounts.UserCredential

  require Logger

  @default_api_version "v61.0"
  @token_buffer_seconds 300

  @contact_fields [
    "Id",
    "Name",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry"
  ]

  @updatable_fields [
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry"
  ]

  @impl SocialScribe.SalesforceApiBehaviour
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    query = String.trim(query)

    if query == "" do
      {:ok, []}
    else
      with_token_refresh(credential, fn cred ->
        with {:ok, base_url} <- base_url(cred) do
          sosl = sosl_query(query)

          case Tesla.get(client(base_url, cred.token), data_path("/search"), query: [q: sosl]) do
            {:ok, %Tesla.Env{status: 200, body: body}} ->
              parse_search_contacts(body)

            {:ok, %Tesla.Env{status: status, body: body}} ->
              {:error, {:api_error, status, body}}

            {:error, reason} ->
              {:error, {:http_error, reason}}
          end
        end
      end)
    end
  end

  @impl SocialScribe.SalesforceApiBehaviour
  def get_contact(%UserCredential{} = credential, contact_id) when is_binary(contact_id) do
    with_token_refresh(credential, fn cred ->
      with {:ok, base_url} <- base_url(cred) do
        fields = Enum.join(@contact_fields, ",")
        path = data_path("/sobjects/Contact/#{contact_id}")

        case Tesla.get(client(base_url, cred.token), path, query: [fields: fields]) do
          {:ok, %Tesla.Env{status: 200, body: body}} ->
            {:ok, format_contact(body)}

          {:ok, %Tesla.Env{status: 404}} ->
            {:error, :not_found}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end
    end)
  end

  @impl SocialScribe.SalesforceApiBehaviour
  def update_contact(%UserCredential{} = credential, contact_id, updates)
      when is_binary(contact_id) and is_map(updates) do
    allowed_updates = Map.take(updates, @updatable_fields)

    if map_size(allowed_updates) == 0 do
      {:error, :no_allowed_updates}
    else
      with_token_refresh(credential, fn cred ->
        with {:ok, base_url} <- base_url(cred) do
          path = data_path("/sobjects/Contact/#{contact_id}")

          case Tesla.patch(client(base_url, cred.token), path, allowed_updates) do
            {:ok, %Tesla.Env{status: status, body: body}} when status in [200, 201] ->
              {:ok, format_contact(body)}

            {:ok, %Tesla.Env{status: 204}} ->
              {:ok, Map.put(allowed_updates, "Id", contact_id)}

            {:ok, %Tesla.Env{status: 404}} ->
              {:error, :not_found}

            {:ok, %Tesla.Env{status: status, body: body}} ->
              {:error, {:api_error, status, body}}

            {:error, reason} ->
              {:error, {:http_error, reason}}
          end
        end
      end)
    end
  end

  defp with_token_refresh(%UserCredential{} = credential, api_call) do
    with {:ok, prepared_credential} <- ensure_valid_token(credential) do
      case api_call.(prepared_credential) do
        {:error, {:api_error, 401, _body}} ->
          retry_with_fresh_token(prepared_credential, api_call)

        other ->
          other
      end
    end
  end

  defp retry_with_fresh_token(credential, api_call) do
    case refresh_credential(credential) do
      {:ok, refreshed_credential} ->
        api_call.(refreshed_credential)

      {:error, reason} ->
        {:error, {:token_refresh_failed, reason}}
    end
  end

  defp ensure_valid_token(%UserCredential{expires_at: nil} = credential), do: {:ok, credential}

  defp ensure_valid_token(%UserCredential{} = credential) do
    if DateTime.compare(
         credential.expires_at,
         DateTime.add(DateTime.utc_now(), @token_buffer_seconds, :second)
       ) == :lt do
      refresh_credential(credential)
    else
      {:ok, credential}
    end
  end

  defp refresh_credential(%UserCredential{} = credential) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, [])
    client_id = config[:client_id]
    client_secret = config[:client_secret]
    site = config[:site] || "https://login.salesforce.com"

    if is_binary(credential.refresh_token) and credential.refresh_token != "" and
         is_binary(client_id) and client_id != "" and is_binary(client_secret) and
         client_secret != "" do
      body = %{
        grant_type: "refresh_token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: credential.refresh_token
      }

      token_url = "#{site}/services/oauth2/token"

      case Tesla.post(oauth_client(), token_url, body) do
        {:ok, %Tesla.Env{status: 200, body: response}} ->
          attrs = refreshed_token_attrs(credential, response)
          Accounts.update_user_credential(credential, attrs)

        {:ok, %Tesla.Env{status: status, body: body}} ->
          Logger.error("Salesforce token refresh failed: #{status} - #{inspect(body)}")
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    else
      {:error, :invalid_refresh_configuration}
    end
  end

  defp refreshed_token_attrs(credential, response) do
    expires_in = response["expires_in"] || 3600

    metadata =
      credential.metadata
      |> normalize_metadata()
      |> maybe_put("instance_url", response["instance_url"])
      |> maybe_put("id_url", response["id"])

    %{
      token: response["access_token"],
      refresh_token: response["refresh_token"] || credential.refresh_token,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second),
      metadata: metadata
    }
  end

  defp data_path(path) do
    "/services/data/#{api_version()}#{path}"
  end

  defp parse_search_contacts(%{"searchRecords" => records}) when is_list(records) do
    {:ok, Enum.map(records, &format_search_contact/1)}
  end

  defp parse_search_contacts(nil), do: {:ok, []}
  defp parse_search_contacts(%{} = body) when map_size(body) == 0, do: {:ok, []}
  defp parse_search_contacts(""), do: {:ok, []}

  defp parse_search_contacts(body) do
    {:error, {:malformed_response, body}}
  end

  defp api_version do
    Application.get_env(:social_scribe, :salesforce_api_version, @default_api_version)
  end

  defp base_url(%UserCredential{} = credential) do
    instance_url =
      credential.metadata
      |> normalize_metadata()
      |> Map.get("instance_url")

    if is_binary(instance_url) and instance_url != "" do
      {:ok, instance_url}
    else
      {:error, :missing_instance_url}
    end
  end

  defp client(base_url, access_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  defp oauth_client do
    Tesla.client([
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ])
  end

  defp sosl_query(term) do
    escaped = String.replace(term, "'", "\\\\'")
    "FIND {#{escaped}} IN ALL FIELDS RETURNING Contact(Id, Name, Email, Phone LIMIT 10)"
  end

  defp format_search_contact(record) do
    %{
      id: record["Id"],
      name: record["Name"],
      email: record["Email"],
      phone: record["Phone"]
    }
  end

  defp format_contact(record) when is_map(record) do
    %{
      id: record["Id"],
      name: record["Name"],
      firstname: record["FirstName"],
      lastname: record["LastName"],
      email: record["Email"],
      phone: record["Phone"],
      mobilephone: record["MobilePhone"],
      title: record["Title"],
      mailing_street: record["MailingStreet"],
      mailing_city: record["MailingCity"],
      mailing_state: record["MailingState"],
      mailing_postal_code: record["MailingPostalCode"],
      mailing_country: record["MailingCountry"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_other), do: %{}
end
