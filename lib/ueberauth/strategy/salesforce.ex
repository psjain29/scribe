defmodule Ueberauth.Strategy.Salesforce do
  @moduledoc """
  Ueberauth strategy for connecting Salesforce accounts.
  """

  use Ueberauth.Strategy,
    uid_field: :external_account_id,
    default_scope: "api refresh_token",
    oauth2_module: Ueberauth.Strategy.Salesforce.OAuth

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info
  alias Ueberauth.Strategy.Salesforce.OAuth

  @doc """
  Starts Salesforce OAuth request flow with state protection.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes, redirect_uri: callback_url(conn)]
      |> with_optional(:prompt, conn)
      |> with_optional(:display, conn)
      |> with_param(:prompt, conn)
      |> with_param(:display, conn)
      |> with_state_param(conn)

    redirect!(conn, OAuth.authorize_url!(opts))
  end

  @doc """
  Handles Salesforce callback outcomes: provider error, code exchange, or missing code.
  """
  def handle_callback!(conn)

  def handle_callback!(%Plug.Conn{params: %{"error" => error} = params} = conn) do
    description = params["error_description"] || "Authorization failed"
    set_errors!(conn, [error(error, description)])
  end

  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]

    case OAuth.get_access_token([code: code], opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received from Salesforce")])
  end

  @doc """
  Clears strategy-private token/user payloads from the connection.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:salesforce_token, nil)
    |> put_private(:salesforce_user, nil)
  end

  @doc """
  Returns stable account UID used by Ueberauth auth struct.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string()

    conn.private.salesforce_user[uid_field]
  end

  @doc """
  Maps OAuth token payload into Ueberauth credentials struct.
  """
  def credentials(conn) do
    token = conn.private.salesforce_token

    %Credentials{
      expires: true,
      expires_at: token.expires_at,
      scopes: String.split(token.other_params["scope"] || "", " "),
      token: token.access_token,
      refresh_token: token.refresh_token,
      token_type: token.token_type
    }
  end

  @doc """
  Builds user-facing account info for persistence and display.
  """
  def info(conn) do
    user = conn.private.salesforce_user
    email = user["email"] || user["preferred_username"]
    name = user["display_name"] || email || user["user_id"] || "Salesforce User"

    %Info{
      email: email,
      name: name
    }
  end

  @doc """
  Exposes raw token and identity payload for downstream use.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.salesforce_token,
        user: conn.private.salesforce_user
      }
    }
  end

  # Fetches Salesforce identity after token exchange and stores it in conn.
  defp fetch_user(conn, token) do
    conn = put_private(conn, :salesforce_token, token)

    case OAuth.get_identity(token) do
      {:ok, user} ->
        put_private(conn, :salesforce_user, user)

      {:error, reason} ->
        set_errors!(conn, [error("identity_error", reason)])
    end
  end

  # Merges runtime query params into request options.
  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  # Applies configured strategy options when present.
  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
