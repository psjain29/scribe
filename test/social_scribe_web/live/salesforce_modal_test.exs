defmodule SocialScribeWeb.SalesforceModalTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import Mox

  setup :verify_on_exit!

  describe "Salesforce Modal" do
    setup %{conn: conn} do
      user = user_fixture()
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        salesforce_credential: salesforce_credential
      }
    end

    test "renders modal when navigating to salesforce route", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      assert has_element?(view, "#salesforce-modal-wrapper")
      assert has_element?(view, "h2", "Update in Salesforce")
      assert has_element?(view, "label", "Select Contact")
    end

    test "search input and dropdown render contacts", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, query ->
        assert query == "Alex"
        {:ok, contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Alex Taylor"
      assert html =~ "alex.taylor@example.test"
    end

    test "single-character input shows helper text and does not query API", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "A"})

      :timer.sleep(200)

      assert render(view) =~ "Please enter at least 2 characters to search."
    end

    test "selecting a contact fetches details and renders suggestion rows", %{
      conn: conn,
      meeting: meeting
    } do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000",
        mobilephone: nil,
        title: "Advisor",
        mailing_street: nil,
        mailing_city: "Denver",
        mailing_state: nil,
        mailing_postal_code: nil,
        mailing_country: "USA"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, contact_id ->
        assert contact_id == "0031"
        {:ok, contact}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn provider, _meeting ->
        assert provider == "salesforce"

        {:ok,
         [
           %{
             "field" => "phone",
             "suggested_value" => "555-2000",
             "reason" => "Client shared a new phone number"
           }
         ]}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      assert eventually(fn ->
               html = render(view)
               html =~ "Phone" and html =~ "555-2000" and html =~ "Update Salesforce"
             end)
    end

    test "shows inline error when AI suggestion generation fails", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, "0031" -> {:ok, contact} end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn "salesforce", _meeting ->
        {:error, {:api_error, 429, %{}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      assert eventually(fn ->
               render(view) =~ "Failed to load Salesforce contact details. Please try again."
             end)
    end

    test "applies selected Salesforce updates and shows success flash", %{
      conn: conn,
      meeting: meeting
    } do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, "0031" -> {:ok, contact} end)
      |> expect(:update_contact, fn _credential, "0031", payload ->
        assert payload == %{"Phone" => "555-2000"}
        {:ok, %{"Id" => "0031", "Phone" => "555-2000"}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn "salesforce", _meeting ->
        {:ok, [%{"field" => "phone", "suggested_value" => "555-2000", "reason" => "New number"}]}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      assert eventually(fn -> render(view) =~ "555-2000" end)

      view
      |> element("form[phx-submit='apply_updates']")
      |> render_submit()

      assert eventually(fn ->
               render(view) =~ "Successfully updated 1 field(s) in Salesforce"
             end)
    end

    test "shows inline error when Salesforce update fails", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, "0031" -> {:ok, contact} end)
      |> expect(:update_contact, fn _credential, "0031", _payload ->
        {:error, {:api_error, 500, %{}}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_crm_suggestions, fn "salesforce", _meeting ->
        {:ok, [%{"field" => "phone", "suggested_value" => "555-2000", "reason" => "New number"}]}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      assert eventually(fn -> render(view) =~ "555-2000" end)

      view
      |> element("form[phx-submit='apply_updates']")
      |> render_submit()

      assert eventually(fn ->
               render(view) =~ "Failed to update Salesforce contact. Please try again."
             end)
    end

    test "shows loading state while search is in flight", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        Process.sleep(250)
        {:ok, contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      assert eventually(fn -> render(view) =~ "Searching..." end)
      assert eventually(fn -> render(view) =~ "Alex Taylor" end)
    end

    test "renders inline error and remains interactive after search failure", %{
      conn: conn,
      meeting: meeting
    } do
      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:error, {:api_error, 500, %{}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Failed to search Salesforce contacts. Please try again."
      assert has_element?(view, "input[phx-keyup='contact_search']")
    end

    test "shows inline error for malformed Salesforce search response", %{
      conn: conn,
      meeting: meeting
    } do
      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:error, {:malformed_response, %{"unexpected" => [%{"id" => "0031"}]}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      html = render(view)

      assert html =~
               "Salesforce returned an unexpected contact search response. Please try again."

      assert has_element?(view, "input[phx-keyup='contact_search']")
    end
  end

  describe "Salesforce Modal without credential" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting
      }
    end

    test "meeting page hides Salesforce integration card", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "Salesforce Integration"
      refute html =~ "Update Salesforce Contact"
    end

    test "salesforce route does not render modal", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      refute html =~ "salesforce-modal-wrapper"
      refute html =~ "Update in Salesforce"
    end
  end

  defp meeting_fixture_with_transcript(user) do
    meeting = meeting_fixture(%{})
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _updated_event} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Advisor",
            "words" => [
              %{"text" => "Let's"},
              %{"text" => "review"},
              %{"text" => "your"},
              %{"text" => "contact"},
              %{"text" => "details"}
            ]
          }
        ]
      }
    })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(25)
      eventually(fun, attempts - 1)
    end
  end
end
