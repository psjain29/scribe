defmodule Ueberauth.Strategy.Salesforce.OAuth do
  @moduledoc """
  OAuth2 client helper for Salesforce authorization/token endpoints.
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://login.salesforce.com",
    authorize_url: "/services/oauth2/authorize",
    token_url: "/services/oauth2/token"
  ]

  @doc """
  Builds the OAuth2 client using runtime Salesforce configuration.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Generates Salesforce authorization URL.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  @doc """
  Exchanges authorization code for access/refresh tokens.
  """
  def get_access_token(params \\ [], opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    params =
      params
      |> Keyword.put(:client_id, config[:client_id])
      |> Keyword.put(:client_secret, config[:client_secret])

    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}} ->
        {:ok, token}

      {:ok, %OAuth2.Client{token: nil}} ->
        {:error, {"no_token", "No token returned from Salesforce"}}

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Response{body: %{"error" => error}}} ->
        {:error, {error, "Salesforce token exchange failed"}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"oauth2_error", to_string(reason)}}

      {:error, reason} ->
        {:error, {"oauth2_error", inspect(reason)}}
    end
  end

  @doc """
  Fetches Salesforce identity payload from token `id` endpoint.
  """
  def get_identity(%OAuth2.AccessToken{} = token) do
    identity_url = token.other_params["id"]

    if is_binary(identity_url) and identity_url != "" do
      case Tesla.get(http_client(token.access_token), identity_url) do
        {:ok, %Tesla.Env{status: 200, body: body}} when is_map(body) ->
          {:ok, Map.put(body, "external_account_id", external_account_id(body))}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, "Failed to fetch Salesforce identity: #{status} - #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Salesforce identity request failed: #{inspect(reason)}"}
      end
    else
      {:error, "Salesforce identity URL missing in token response"}
    end
  end

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_param(:grant_type, "authorization_code")
    |> put_header("Content-Type", "application/x-www-form-urlencoded")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  # Uses bearer auth for identity endpoint calls.
  defp http_client(access_token) do
    Tesla.client([
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{access_token}"}]}
    ])
  end

  # Builds a stable external account key for multi-connection support.
  defp external_account_id(%{"organization_id" => org_id, "user_id" => user_id})
       when is_binary(org_id) and is_binary(user_id) do
    "#{org_id}:#{user_id}"
  end

  defp external_account_id(_body), do: nil
end
