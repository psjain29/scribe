defmodule SocialScribeWeb.AuthControllerTest do
  use SocialScribeWeb.ConnCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribeWeb.AuthController

  describe "OAuth provider failure callbacks" do
    test "4.1 access_denied returns friendly authorization denied message", %{conn: conn} do
      conn = failure_callback(conn, "access_denied")

      assert redirected_to(conn) == ~p"/dashboard/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not connect to Salesforce: Authorization was denied. Please try again and click Allow if you consent."
    end

    test "4.2 csrf without state returns invalid callback message", %{conn: conn} do
      conn = failure_callback(conn, "csrf_attack")

      assert redirected_to(conn) == ~p"/dashboard/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not connect to Salesforce: Connection callback was invalid or incomplete. Please try again from Settings."
    end

    test "4.3 csrf with state returns invalid session message", %{conn: conn} do
      conn = failure_callback(conn, "csrf_attack", %{"state" => "random-state"})

      assert redirected_to(conn) == ~p"/dashboard/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not connect to Salesforce: Your connection session expired or was invalid. Please try connecting again."
    end

    test "4.4 invalid_client returns token exchange failure message", %{conn: conn} do
      conn = failure_callback(conn, "invalid_client")

      assert redirected_to(conn) == ~p"/dashboard/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not connect to Salesforce: We could not complete the secure token exchange. Please reconnect and try again."
    end

    test "4.5 unknown error key returns fallback message", %{conn: conn} do
      conn = failure_callback(conn, "totally_unknown_error")

      assert redirected_to(conn) == ~p"/dashboard/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not connect to Salesforce: An unexpected error occurred. Please try again."
    end
  end

  defp failure_callback(conn, message_key, params \\ %{}) do
    user = user_fixture()
    failure = failure_with_key(message_key)

    conn =
      conn
      |> log_in_user(user)
      |> Phoenix.Controller.fetch_flash([])
      |> Plug.Conn.assign(:current_user, user)
      |> Plug.Conn.assign(:ueberauth_failure, failure)

    AuthController.callback(conn, Map.merge(%{"provider" => "salesforce"}, params))
  end

  defp failure_with_key(message_key) do
    %Ueberauth.Failure{
      errors: [
        %Ueberauth.Failure.Error{
          message_key: message_key,
          message: "oauth_failure"
        }
      ]
    }
  end
end
