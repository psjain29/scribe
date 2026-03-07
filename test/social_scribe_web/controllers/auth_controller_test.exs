defmodule SocialScribeWeb.AuthControllerTest do
  use SocialScribeWeb.ConnCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribeWeb.AuthController

  describe "OAuth provider failure callbacks" do
    test "salesforce deny redirects to settings with safe flash message", %{conn: conn} do
      user = user_fixture()

      failure = %Ueberauth.Failure{
        errors: [
          %Ueberauth.Failure.Error{
            message: "end-user denied authorization",
            message_key: "access_denied"
          }
        ]
      }

      conn =
        conn
        |> log_in_user(user)
        |> Phoenix.Controller.fetch_flash([])
        |> Plug.Conn.assign(:current_user, user)
        |> Plug.Conn.assign(:ueberauth_failure, failure)

      conn = AuthController.callback(conn, %{"provider" => "salesforce"})

      assert redirected_to(conn) == ~p"/dashboard/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Could not connect Salesforce"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "end-user denied authorization"
    end
  end
end
