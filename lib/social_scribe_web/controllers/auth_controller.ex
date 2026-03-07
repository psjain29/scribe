defmodule SocialScribeWeb.AuthController do
  @moduledoc """
  Handles OAuth request/callback flows for sign-in and provider connections.
  """

  use SocialScribeWeb, :controller

  alias SocialScribe.FacebookApi
  alias SocialScribe.Accounts
  alias SocialScribeWeb.UserAuth
  plug Ueberauth

  require Logger

  @sf_authorization_denied_message "Could not connect to Salesforce: Authorization was denied. Please try again and click Allow if you consent."
  @sf_callback_invalid_message "Could not connect to Salesforce: Connection callback was invalid or incomplete. Please try again from Settings."
  @sf_session_invalid_message "Could not connect to Salesforce: Your connection session expired or was invalid. Please try connecting again."
  @sf_token_exchange_failed_message "Could not connect to Salesforce: We could not complete the secure token exchange. Please reconnect and try again."
  @sf_fallback_message "Could not connect to Salesforce: An unexpected error occurred. Please try again."

  @doc """
  Handles the initial request to the provider (e.g., Google).
  Ueberauth's plug will redirect the user to the provider's consent page.
  """
  def request(conn, _params) do
    render(conn, :request)
  end

  @doc """
  Handles OAuth callbacks for login and connected account flows.
  """
  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user}} = conn, %{
        "provider" => "google"
      })
      when not is_nil(user) do
    Logger.info("Google OAuth")
    Logger.info(auth)

    case Accounts.find_or_create_user_credential(user, auth) do
      {:ok, _credential} ->
        conn
        |> put_flash(:info, "Google account added successfully.")
        |> redirect(to: ~p"/dashboard/settings")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not add Google account.")
        |> redirect(to: ~p"/dashboard/settings")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user}} = conn, %{
        "provider" => "linkedin"
      }) do
    Logger.info("LinkedIn OAuth")
    Logger.info(auth)

    case Accounts.find_or_create_user_credential(user, auth) do
      {:ok, credential} ->
        Logger.info("credential")
        Logger.info(credential)

        conn
        |> put_flash(:info, "LinkedIn account added successfully.")
        |> redirect(to: ~p"/dashboard/settings")

      {:error, reason} ->
        Logger.error(reason)

        conn
        |> put_flash(:error, "Could not add LinkedIn account.")
        |> redirect(to: ~p"/dashboard/settings")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user}} = conn, %{
        "provider" => "facebook"
      })
      when not is_nil(user) do
    Logger.info("Facebook OAuth")
    Logger.info(auth)

    case Accounts.find_or_create_user_credential(user, auth) do
      {:ok, credential} ->
        case FacebookApi.fetch_user_pages(credential.uid, credential.token) do
          {:ok, facebook_pages} ->
            facebook_pages
            |> Enum.each(fn page ->
              Accounts.link_facebook_page(user, credential, page)
            end)

          _ ->
            :ok
        end

        conn
        |> put_flash(
          :info,
          "Facebook account added successfully. Please select a page to connect."
        )
        |> redirect(to: ~p"/dashboard/settings/facebook_pages")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not add Facebook account.")
        |> redirect(to: ~p"/dashboard/settings")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user}} = conn, %{
        "provider" => "hubspot"
      })
      when not is_nil(user) do
    Logger.info("HubSpot OAuth")
    Logger.info(inspect(auth))

    hub_id = to_string(auth.uid)

    credential_attrs = %{
      user_id: user.id,
      provider: "hubspot",
      uid: hub_id,
      token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at:
        (auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at)) ||
          DateTime.add(DateTime.utc_now(), 3600, :second),
      email: auth.info.email
    }

    case Accounts.find_or_create_hubspot_credential(user, credential_attrs) do
      {:ok, _credential} ->
        Logger.info("HubSpot account connected for user #{user.id}, hub_id: #{hub_id}")

        conn
        |> put_flash(:info, "HubSpot account connected successfully!")
        |> redirect(to: ~p"/dashboard/settings")

      {:error, reason} ->
        Logger.error("Failed to save HubSpot credential: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Could not connect HubSpot account.")
        |> redirect(to: ~p"/dashboard/settings")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: auth, current_user: user}} = conn, %{
        "provider" => "salesforce"
      })
      when not is_nil(user) do
    Logger.info("Salesforce OAuth")
    Logger.info(inspect(auth))

    credential_attrs = salesforce_credential_attrs(user, auth)

    case credential_attrs do
      {:ok, attrs} ->
        case Accounts.find_or_create_salesforce_credential(user, attrs) do
          {:ok, _credential} ->
            conn
            |> put_flash(:info, "Salesforce account connected successfully!")
            |> redirect(to: ~p"/dashboard/settings")

          {:error, reason} ->
            Logger.error("Failed to save Salesforce credential: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Could not connect Salesforce account. Please try again.")
            |> redirect(to: ~p"/dashboard/settings")
        end

      {:error, reason} ->
        Logger.error("Salesforce OAuth callback rejected: #{reason}")

        conn
        |> put_flash(:error, reason)
        |> redirect(to: ~p"/dashboard/settings")
    end
  end

  def callback(
        %{assigns: %{ueberauth_failure: failure, current_user: user}} = conn,
        %{
          "provider" => provider
        } = params
      )
      when not is_nil(user) and
             provider in ["google", "linkedin", "facebook", "hubspot", "salesforce"] do
    Logger.error("OAuth failure for connected provider #{provider}: #{inspect(failure)}")

    conn
    |> put_flash(:error, oauth_failure_message(provider, failure, params))
    |> redirect(to: ~p"/dashboard/settings")
  end

  def callback(%{assigns: %{ueberauth_auth: _auth}} = conn, %{"provider" => provider})
      when provider in ["hubspot", "salesforce"] do
    conn
    |> put_flash(
      :error,
      "Please sign in first, then connect #{String.capitalize(provider)} from settings."
    )
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    Logger.info("Google OAuth Login")
    Logger.info(auth)

    case Accounts.find_or_create_user_from_oauth(auth) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)

      {:error, reason} ->
        Logger.info("error")
        Logger.info(reason)

        conn
        |> put_flash(:error, "There was an error signing you in.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, _params) do
    Logger.error("OAuth Login")
    Logger.error(conn)

    conn
    |> put_flash(:error, "There was an error signing you in. Please try again.")
    |> redirect(to: ~p"/")
  end

  # Builds validated persistence attrs from Salesforce OAuth payload.
  defp salesforce_credential_attrs(user, auth) do
    raw_info = if(auth.extra && auth.extra.raw_info, do: auth.extra.raw_info, else: %{})
    raw_user = raw_info[:user] || raw_info["user"] || %{}
    raw_token = raw_info[:token] || raw_info["token"] || %{}
    other_params = Map.get(raw_token, :other_params) || Map.get(raw_token, "other_params") || %{}
    instance_url = other_params["instance_url"]
    id_url = other_params["id"]
    external_account_id = salesforce_external_account_id(raw_user)

    cond do
      is_nil(external_account_id) ->
        {:error, "Salesforce did not return account identity. Please reconnect and retry."}

      is_nil(instance_url) or instance_url == "" ->
        {:error, "Salesforce did not return an instance URL. Please reconnect and retry."}

      true ->
        {:ok,
         %{
           user_id: user.id,
           provider: "salesforce",
           uid: external_account_id,
           external_account_id: external_account_id,
           token: auth.credentials.token,
           refresh_token: auth.credentials.refresh_token,
           expires_at:
             (auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at)) ||
               DateTime.add(DateTime.utc_now(), 3600, :second),
           email: salesforce_email(auth, raw_user, external_account_id),
           metadata: %{
             "instance_url" => instance_url,
             "id_url" => id_url
           }
         }}
    end
  end

  # Derives a stable account key used for multi-account uniqueness.
  defp salesforce_external_account_id(raw_user) do
    with org when is_binary(org) <- raw_user["organization_id"],
         user_id when is_binary(user_id) <- raw_user["user_id"] do
      "#{org}:#{user_id}"
    else
      _ -> raw_user["external_account_id"]
    end
  end

  # Uses provider email when present, then a deterministic fallback.
  defp salesforce_email(auth, raw_user, external_account_id) do
    auth.info.email || raw_user["email"] || raw_user["preferred_username"] ||
      "salesforce-#{external_account_id}@local.invalid"
  end

  # Keeps provider failure messages short and user-actionable.
  defp oauth_failure_message("salesforce", failure, params) do
    salesforce_oauth_failure_message(failure, params)
  end

  defp oauth_failure_message(provider, failure, _params) do
    provider_name = String.capitalize(provider)
    details = format_ueberauth_errors(failure)

    if details == "" do
      "Could not connect #{provider_name}. Please try again."
    else
      "Could not connect #{provider_name}: #{details}"
    end
  end

  # Converts Ueberauth error structs into a compact message string.
  defp format_ueberauth_errors(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(&format_ueberauth_error/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  defp format_ueberauth_errors(_failure), do: ""

  defp format_ueberauth_error(%{message: message}) when is_binary(message) and message != "",
    do: message

  defp format_ueberauth_error(%{message_key: key}) when not is_nil(key), do: to_string(key)

  defp format_ueberauth_error(%{"message" => message}) when is_binary(message) and message != "",
    do: message

  defp format_ueberauth_error(%{"message_key" => key}) when not is_nil(key), do: to_string(key)

  defp format_ueberauth_error(error) when is_struct(error) do
    error
    |> Map.from_struct()
    |> format_ueberauth_error()
  end

  defp format_ueberauth_error(_), do: ""

  defp salesforce_oauth_failure_message(failure, params) do
    keys = oauth_failure_keys(failure)

    cond do
      "access_denied" in keys ->
        @sf_authorization_denied_message

      "missing_code" in keys ->
        @sf_callback_invalid_message

      "csrf_attack" in keys and Map.has_key?(params, "state") ->
        @sf_session_invalid_message

      "csrf_attack" in keys ->
        @sf_callback_invalid_message

      Enum.any?(
        keys,
        &(&1 in ["invalid_client", "invalid_client_id", "invalid_grant", "identity_error"])
      ) ->
        @sf_token_exchange_failed_message

      true ->
        @sf_fallback_message
    end
  end

  defp oauth_failure_keys(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(&oauth_failure_key/1)
    |> Enum.reject(&is_nil/1)
  end

  defp oauth_failure_keys(_), do: []

  defp oauth_failure_key(%{message_key: key}) when is_binary(key), do: key
  defp oauth_failure_key(%{"message_key" => key}) when is_binary(key), do: key

  defp oauth_failure_key(error) when is_struct(error) do
    error
    |> Map.from_struct()
    |> oauth_failure_key()
  end

  defp oauth_failure_key(_), do: nil
end
